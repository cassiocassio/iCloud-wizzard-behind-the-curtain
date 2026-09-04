# iCloud — the wizard behind the curtain

**Ground truth for app developers about evicted ("dataless") iCloud Drive files:
what a third-party process can know, what it can control, and how to represent
that to a user truthfully. Measured on macOS 26.4.1, 4 September 2026.**

Apple's goal here deserves applause. A person should be able to simply not care
where their data happens to be — on this device or in the cloud — and trust that
wherever it is, it is kept; should not be limited by the hardware in front of them,
nor have to think about running out of space, nor treat the location of their files
as their job any more. Location becomes an implementation detail beneath the
surface, while the surface keeps the familiar shape: a disk, whatever that is, with
files in folders. For almost every app that illusion is exactly right, and the
system goes to real lengths to keep it intact.

This repo is for the moment an app has to set an expectation anyway: a wait it
cannot hide, a verdict it has to give ("is my stuff backed up?"), a promise it is
tempted to make. The aim is the best useful representation of the truth in a UI —
without misleading anyone, and without breaking the mental model the system has
built for them.

Everything below carries a tag: **MEASURED** (this Mac, date given, probe in
[`probes/`](probes/), output in [`results/`](results/)), **APPLE** (documentation,
man page, header), **SOURCE** (read in Apple's open source), **COMMUNITY**, or
**INFERRED**. A claim without a tag is a claim nobody checked.

## 1. The two facts that explain everything else

**A placeholder is a file with `SF_DATALESS` set.** Its `st_size` is the real
logical size; its bytes are elsewhere. `stat` reports the flag with no side
effects (`stat -f '%Sf' <path>` prints `dataless`). — **APPLE** (`chflags(2)`)

**What happens when you touch its *contents* is decided by your process's
materialisation policy, and you inherited that policy from whoever launched you.**
`IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES`, read with `getiopolicy_np`:

| policy | on a contents access (`read`, `mmap`, `copyfile`, `clonefile`) |
|---|---|
| **ON (2)** | blocks until the provider delivers the bytes, then proceeds — no timeout |
| **OFF (1)** | fails at once with **`EDEADLK`, errno 11** — the kernel's errno for "materialisation refused by policy"; nothing is locked |

| who launched you | policy you inherit |
|---|---|
| a GUI app — Terminal, Xcode, a sandboxed app and its child processes | **ON** |
| launchd — a LaunchAgent or LaunchDaemon with no policy key, `launchctl submit` | **OFF** |

— **MEASURED** ([results §1](results/2026-09-04-macos-26.4.1.md)), **APPLE**
(`setiopolicy_np(3)`), **SOURCE** (xnu `vfs_syscalls.c`). The launchd.plist key
`MaterializeDatalessFiles` flips a job to ON — **APPLE** (`launchd.plist(5)`).

So the same binary *hangs* from Terminal and *fails instantly* from a LaunchAgent,
and neither is a bug. Most "I can't reproduce it" stories in this area are the
reporter and the reproducer running under different policies.

## 2. Which operations touch the contents

| operation on a dataless file | policy OFF | policy ON |
|---|---|---|
| `lstat`, `stat`, `getattrlist`, `URLResourceValues` | fine, stays dataless | same |
| `open(O_RDONLY)` | fine, stays dataless | same |
| `mmap(PROT_READ)` | **EDEADLK**, stays dataless | **the `mmap` call itself downloads the file** |
| `read` / `pread`, `Data(contentsOf:)` | **EDEADLK** | blocks, then reads |
| `clonefile` (dataless source), `copyfile`, `FileManager.copyItem` | **EDEADLK** | blocks, then copies |
| `rename` a fresh file **onto** a placeholder | works | works |
| `unlink` a placeholder | works — metadata only | works |
| `fcntl(F_NOCACHE)` | no effect on any of the above | same |

— **MEASURED** ([results §2–3](results/2026-09-04-macos-26.4.1.md)). One caveat
from Apple: `stat`/`getattrlist` **do** materialise dataless *directories* on the
path — **APPLE** (TN3150).

## 3. What you can know, control, and not

| | know | control | not |
|---|---|---|---|
| Is this a placeholder? | **yes** — `SF_DATALESS`; on iCloud also `ubiquitousItemDownloadingStatus` | | |
| Is it being fetched right now? | iCloud: `ubiquitousItemIsDownloading` (Bool). Others: **not found** | | |
| How far along? | iCloud: `NSMetadataUbiquitousItemPercentDownloadedKey` exists on paper — **unmeasured** from a sandboxed app. Others: **not found**. `st_blocks` reads 0 until 100 % | | an ETA |
| Ask for the bytes | | `startDownloadingUbiquitousItem` (returns in 1–3 ms, lands ~750 ms later for a tiny file; also works on Dropbox); or any read under ON; hidden `brctl download` | |
| Give the bytes back | | `evictUbiquitousItem`; hidden `brctl evict` | |
| Keep them local | | only Finder's *Keep Downloaded* (undocumented xattr `com.apple.fileprovider.pinned`, ten items at a time) or Optimise Mac Storage off | when the system will evict again — 2 min once, > 4 min another time |
| Will it be evicted at all? | | | no published threshold; **31,134 of 36,201 files were evicted with 189 GiB free** — age of access, not space |
| Is it *uploaded* (safe in the cloud)? | **yes**, per file — `ubiquitousItemIsUploaded` / `IsUploading`; a package is one item and its contents answer `nil` | | |
| Cancel mid-file | | | a blocking read parks in the kernel; only your own bound returns control, at the next file |
| Change policy for this process | `getiopolicy_np` | `setiopolicy_np` (thread or process); `MaterializeDatalessFiles` for a job | the *system* default |

`NSFileCoordinator` deserves its own line: inside a coordinated accessor the file
is materialised **regardless of your policy** (Foundation uses per-thread override
flags — **SOURCE**). It is a reader's tool for "give me the bytes"; it is not a way
to avoid the wait, and it does nothing for a writer.

## 4. What this means for your UI — reader or writer, decide which

**Where the illusion cracks.** A researcher clicks a 4K recording of a focus group
that has not been on the actual Mac for some weeks. Nothing happens for a while.
There is an uncomfortable *is it broken or not?* moment, and the app has no accurate
statement of activity to offer and no way to set an expectation about how long the
file might take to arrive. Or they drag what look like ordinary video files into a
project to analyse, and the import appears to hang while the bytes are fetched. In
both cases the person did nothing wrong, the system is doing exactly what it
promised, and the app is the only party that could have said so.

**A reader** (you need the bytes: importing, playing, indexing) may wait, and the
truthful UI is a *label with a name and a bound*: "Waiting for iCloud Drive…",
"Downloading from OneDrive…", then "still waiting after N minutes — try again /
skip". Detect with the flag, ask with `startDownloadingUbiquitousItem`, poll with a
wall-clock bound, then read. A spinner with no provider and no bound over a blocking
read is the one thing not to ship — it is the hang. No shipping Mac app shows a wait
label or a per-file cancel today; the label is a small step past the field, and it
costs one line.

**The third illusion, and it is the writer's.** You copied `~/Code` into a folder
inside iCloud Drive, the copy finished, the dot went green: your files are backed up.
The truth is that a file written into `~/Library/Mobile Documents` is a *local* file
until the upload daemon gets to it, and if the laptop goes into the canal in that
window the "backup" goes with it. Measured on this Mac, 4 Sep 2026, from the backup
tool's own state records: the last byte of a 6.7 GB mirror reached the cloud
**63 minutes** after the copy finished on the morning run and **2 minutes** after
the evening one. Same tool, same day, same folder. The only honest verdict is two
facts with two ages — *copied* (the transfer) and *uploaded* (per file,
`ubiquitousItemIsUploaded`) — and "backed up" is the second one, never the first.

**A writer** (you put files *into* iCloud: a mirror, an export, a sync) must never
read the destination: under OFF the read aborts, under ON it downloads stale bytes
you are about to overwrite. Copy to a temp name *beside* the destination and
`rename` onto the placeholder — nothing exists at the temp path, so nothing is
mmapped, and the old file survives until the new one lands. Verify by metadata
(size, mtime, the flag), and report **copied** and **uploaded** as two different
facts, each with its age.

**Both** may always: count placeholders, name the provider, set a bound, carry the
age of every verdict. **Neither** may promise that a file will stay local, that
eviction will not happen, or how long a fetch will take.

The mockup [`mockups/what-you-can-tell-the-user.html`](mockups/what-you-can-tell-the-user.html)
draws the three lists — possible, not possible, misleading — as rows you can
compare against your own.

## 5. Beliefs that turned out to be wrong

Each of these was written down in good faith by a careful person and corrected by
a measurement in this repo.

- *"`EDEADLK` is errno 35."* — 35 is Linux's; macOS is **11**.
- *"Reads get `EDEADLK`, copies hang."* — the axis is the caller's **policy**, not
  the operation.
- *"`--whole-file` stops rsync reading the destination."* — Apple's openrsync mmaps
  the destination to hash it whatever `-W` says; the flag is never consulted in the
  downloader (**SOURCE**, `openrsync/downloader.c`).
- *"`brctl download` / `brctl evict` no longer exist."* — hidden from the usage,
  still working. Running them with no path prints the usage, which is how the
  belief formed. `download` is asynchronous.
- *"Pre-materialise the destination, then rsync."* — re-eviction is not on a
  clock, and the download is async; it worked by luck.
- *"`NSFileCoordinator` is the fix."* — for a reader under OFF, yes; for anything
  else, irrelevant.
- *"It won't evict with this much free space."* — 31,134 of 36,201 files, 189 GiB free.
- *"A package's files report `uploaded == false`."* — they report **`nil`**; iCloud
  tracks the package as one item. Counting nil as pending gave a permanent false alarm.
- *"I couldn't reproduce the deadlock."* — it was reproduced by hand, under ON.
  `launchctl submit` reproduces it at will.

## 6. macOS 27

Researched 4 Sep 2026 against beta 8 release notes, the Xcode 27 SDK header
diffs, TN3150's revision history, WWDC26's session list and the community: **nothing
above changes.** No new API for a third-party client to know or control any of it;
`setiopolicy_np`, the ubiquity resource keys, `startDownloadingUbiquitousItem`
and `evictUbiquitousItem` are unchanged; TN3150 is unrevised since 2023. The one
new symbol, `NSFileProviderNamespacePolicy` (`materializeEagerly` / `materializeLazily`),
is declared by a *provider* for its own items — Apple's iCloud extension could use
it; you cannot set it on Apple's items — and is marked `API_UNAVAILABLE` on macOS
and iOS in the beta-1 headers. The default policy for launchd jobs: no change found.
Re-measure when 27 ships; the probes take ten minutes.

## 7. In the wild

[`in-the-wild/`](in-the-wild/) holds cleaned excerpts of two shipping projects by the
same maintainer that meet this from opposite sides — an app that *reads* recordings
out of cloud folders and a backup tool that *writes* a mirror into iCloud Drive —
with a verdict on each piece: what is working for them and what is not.

## 8. Reproduce it

```bash
git clone https://github.com/cassiocassio/iCloud-wizzard-behind-the-curtain
cd iCloud-wizzard-behind-the-curtain/probes && cat README.md
```

Pick a placeholder under 1 KB, run the probes, evict it back. If your numbers
differ from [`results/`](results/), add a file named for your OS version — that is
the point of the repo.

## 9. Sources

[`SOURCES.md`](SOURCES.md) — every Apple document, header, kernel and rsync source
file, vendor note and community post these findings rest on.
