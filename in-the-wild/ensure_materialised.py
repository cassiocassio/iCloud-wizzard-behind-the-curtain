"""Detect a cloud placeholder and fault it in, with a bound — the READER's shape.

Cleaned excerpt of a shipping Python module (Bristlenose, `bristlenose/utils/fs.py`,
Jul–Aug 2026). Runs as a sidecar of a sandboxed Mac app, which inherits
materialisation policy ON — so a plain read() blocks until the bytes arrive, and
"blocks forever on a slow link" is the hazard this bounds.

Verdict, 4 Sep 2026: WORKING for what it is. Five callers; the `on_wait` hook that
would tell the user "downloading from iCloud Drive…" is passed by none of them yet.
Not applicable to a copier writing INTO iCloud — see the README.
"""
from __future__ import annotations

import logging
import os
import threading
from collections.abc import Callable
from pathlib import Path

logger = logging.getLogger(__name__)

# <sys/stat.h> SF_DATALESS. Absent on Linux, hence the getattr guard below.
SF_DATALESS = 0x40000000

# A file-provider fetch on a slow link is a download, not a probe: minutes, not seconds.
MATERIALISE_TIMEOUT_SECONDS = 30 * 60


class CloudFetchTimeoutError(RuntimeError):
    """The placeholder did not materialise in time. Deliberately NOT a 'corrupt file'
    error — 'still downloading' and 'corrupt' want opposite remedies from the user."""


def is_dataless(path: Path) -> bool:
    """True if `path` is a placeholder with no bytes on disk. One stat, no I/O.
    Provider-agnostic: iCloud Drive, OneDrive, Dropbox, Google Drive, Box all set it."""
    try:
        st = os.stat(path)
    except OSError:
        return False
    return bool(getattr(st, "st_flags", 0) & SF_DATALESS)


def cloud_provider_for(path: Path) -> str | None:
    """Human-readable provider for a status line, from the path's shape.
    `~/Library/Mobile Documents/…` is iCloud Drive; `~/Library/CloudStorage/<Provider>-<acct>/…`
    is every File Provider extension, present and future."""
    parts = path.resolve().parts if path.is_absolute() else Path(path).parts
    for i, part in enumerate(parts):
        if part == "Mobile Documents":
            return "iCloud Drive"
        if part == "CloudStorage" and i + 1 < len(parts):
            stem = parts[i + 1].split("-", 1)[0]
            return {
                "GoogleDrive": "Google Drive", "OneDrive": "OneDrive", "Dropbox": "Dropbox",
                "Box": "Box", "ProtonDrive": "Proton Drive",
            }.get(stem, stem or None)
    return None


def ensure_materialised(
    path: Path,
    timeout: float = MATERIALISE_TIMEOUT_SECONDS,
    on_wait: Callable[[Path, str | None], None] | None = None,
) -> bool:
    """Fault a placeholder into local storage before anything reads it.

    Returns True if a fetch was waited on, False if the file was already resident.

    THE BLOCKING READ IS THE TRIGGER. Python has no materialise-this API; under
    policy ON, reading one byte is what makes the provider fetch. So this does not
    avoid the block — it moves it somewhere deliberate, onto a thread the caller can
    bound. No progress is reported because none is observable from POSIX: providers
    stage the download and swap the file in atomically, so `st_blocks` reads 0 until
    it reads 100 %.

    Under policy OFF (a launchd agent, say) the read would fail at once with EDEADLK
    instead of blocking — this function was written for the ON case and does not
    handle that; a copier should not be reading placeholders at all.
    """
    if not is_dataless(path):
        return False

    provider = cloud_provider_for(path)
    logger.info("cloud_fetch_start | file=%s | provider=%s | size_bytes=%s",
                path.name, provider or "unknown", path.stat().st_size)
    if on_wait is not None:
        on_wait(path, provider)

    def _touch() -> None:
        with open(path, "rb") as fh:
            fh.read(1)

    worker = threading.Thread(target=_touch, daemon=True, name="cloud-fetch")
    worker.start()
    worker.join(timeout)

    if worker.is_alive():
        # The daemon thread is abandoned on purpose: it is parked in a kernel read
        # that cannot be interrupted, and the process will exit around it.
        raise CloudFetchTimeoutError(
            f"{path.name} was still being fetched from {provider or 'the cloud'} "
            f"after {int(timeout // 60)} minutes"
        )

    logger.info("cloud_fetch_done | file=%s | provider=%s", path.name, provider or "unknown")
    return True
