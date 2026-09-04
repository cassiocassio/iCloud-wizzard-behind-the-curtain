#!/bin/bash
# Replace a file INSIDE iCloud Drive without ever reading the copy that is there —
# the WRITER's shape. Cleaned excerpt of a shipping backup tool (Stickleback,
# `lib-rsync.sh::remediate_failures`, 1 Sep 2026).
#
# Why not just `rsync src dst`? openrsync (macOS's rsync) opens an existing
# destination and mmaps it to hash it — even with -W — and mmap on a dataless
# placeholder returns EDEADLK when the process runs with materialisation OFF, which
# a launchd agent does. The receiver dies and the WHOLE transfer aborts.
#
# Why not `rm dst` first, then copy? That worked, and for the length of a copy the
# file existed in NEITHER place — the destination is iCloud Drive, so the unlink
# propagates to the cloud and every other device. A run killed in that window
# destroyed the last copy of a just-edited file (the population most likely to be
# in remediation, because a just-written file is what deadlocks).
#
# So: copy to a temp NAME in the same directory (nothing exists there, so nothing
# is mmapped), then `mv` over the placeholder. MEASURED 4 Sep 2026: rename onto a
# dataless placeholder succeeds under both policies; the mirror holds the stale copy
# right up to the instant it holds the fresh one, and never neither.
#
# Verdict, 4 Sep 2026: WORKING per file. NOT YET applied to the bulk pass, which is
# still openrsync and still aborts under launchd — see the README's open decision.
set -u

copy_over_placeholder() {   # <src-file> <dst-path-inside-icloud>
    local src="$1" dst="$2" tmp err
    tmp="$(dirname "$dst")/.$(basename "$dst").tmp.$$"
    if ! err=$(rsync -aW "$src" "$tmp" 2>&1); then     # fresh path: no basis to mmap
        rm -f "$tmp"; printf 'copy failed: %s\n' "${err##*error: }" >&2; return 1
    fi
    if ! mv -f "$tmp" "$dst" 2>/dev/null; then          # atomic; works onto a placeholder
        # Last resort only: dst is a directory where src is a file, or permissions.
        # Even here the temp already holds a complete correct copy.
        rm -rf "$dst" 2>/dev/null || true
        if ! mv -f "$tmp" "$dst" 2>/dev/null; then
            printf 'could not rename onto %s — correct bytes left at %s\n' "$dst" "$tmp" >&2
            return 1
        fi
    fi
    return 0
}

# Usage: copy_over_placeholder ~/Code/project/file "$HOME/Library/Mobile Documents/com~apple~CloudDocs/mirror/project/file"
