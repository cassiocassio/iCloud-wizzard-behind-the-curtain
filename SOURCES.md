# Sources

Everything the README rests on. Tags as in the README. Read 4 September 2026.

## Apple — documentation, man pages, headers

- TN3150 *Getting ready for data-less files* — https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files (revision history: 2023-05-09 first published, no later revision)
- `setiopolicy_np(3)` — https://keith.github.io/xcode-man-pages/setiopolicy_np.3.html ; `sys/resource.h` (`IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES`, `IOPOL_MATERIALIZE_DATALESS_FILES_OFF/ON`)
- `chflags(2)` — https://keith.github.io/xcode-man-pages/chflags.2.html (`SF_DATALESS`; "may not be set or unset from user space")
- `read(2)`, `open(2)`, `clonefile(2)` — local man pages, macOS 26.4.1 CLT SDK (the `[EDEADLK]` dataless entries)
- `launchd.plist(5)` — https://keith.github.io/xcode-man-pages/launchd.plist.5.html (`MaterializeDatalessFiles`); `launch.h`
- `ls(1)` — `-%` "distinguish dataless files"
- `FileManager.startDownloadingUbiquitousItem(at:)` — https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)
- `FileManager.evictUbiquitousItem(at:)` — https://developer.apple.com/documentation/foundation/filemanager/evictubiquitousitem(at:)
- `URLUbiquitousItemDownloadingStatus` — https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus ; `NSURL.h`
- `NSURLUbiquitousItemIsExcludedFromSyncKey` — https://developer.apple.com/documentation/foundation/nsurlubiquitousitemisexcludedfromsynckey
- `NSFileCoordinator` — https://developer.apple.com/documentation/foundation/nsfilecoordinator ; `NSFileCoordinator.h` (`ReadingImmediatelyAvailableMetadataOnly`)
- `NSFileProviderManager.evictItem(identifier:)` — https://developer.apple.com/documentation/fileprovider/nsfileprovidermanager/evictitem(identifier:completionhandler:)
- *Synchronizing the File Provider Extension* — https://developer.apple.com/documentation/fileprovider/synchronizing-the-file-provider-extension
- `NSFileProviderNamespacePolicy` (macOS 27 beta) — https://developer.apple.com/documentation/fileprovider/nsfileprovidernamespacepolicy ; header diff https://github.com/dotnet/macios/wiki/FileProvider-macOS-xcode27.0-b1
- Foundation Xcode 27 b1 header diff — https://github.com/dotnet/macios/wiki/Foundation-macOS-xcode27.0-b1
- macOS 27 release notes — https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes
- Mac User Guide, *Keep Downloaded* (macOS 26) — https://support.apple.com/en-am/guide/mac-help/mchl1a02d711/26/mac ; Optimise Mac Storage — https://support.apple.com/guide/mac-help/sysp4ee93ca4
- Time Machine and AFP in macOS 27 — https://support.apple.com/en-us/102423
- Device-management updates, `com.apple.fileproviderd` payload (macOS 26.4) — https://support.apple.com/guide/deployment/device-management-updates-depd638aa061/1/web/1.0
- Developer Forums: 763344 (Apple staff — coordination downloads the file), 813369 (DTS, `SF_DATALESS` for folders, Jan 2026), 831371 (DTS, `evictItem`, Jun 2026), 823369 (FB22547671, sandbox access after `fileproviderd` restart), 808338, 118663, 690124

## Apple — open source

- xnu `bsd/vfs/vfs_syscalls.c` — https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_syscalls.c ("Namespace Resolver Up-call Mechanism", `vfs_materialize_file`, `vfs_context_dataless_materialization_is_prevented`)
- xnu `bsd/kern/kern_resource.c`, `bsd/kern/kern_mman.c`, `bsd/kern/kern_exec.c` (`PSA_OPTION_DATALESS_IOPOLICY`)
- Apple rsync (openrsync), tag rsync-184 — https://github.com/apple-oss-distributions/rsync (`openrsync/downloader.c`, `fmap.c`, `receiver.c`, `io.c`)
- kristapsdz/openrsync `downloader.c` — https://github.com/kristapsdz/openrsync/blob/master/downloader.c
- GNU rsync `fileio.c` (read-based `map_ptr`, no mmap) — https://github.com/RsyncProject/rsync/blob/master/fileio.c ; `rsync(1)` — https://download.samba.org/pub/rsync/rsync.1

## Community — measurement and explanation

- Howard Oakley, *The Eclectic Light Company*: 2022-02-21 https://eclecticlight.co/2022/02/21/can-you-back-up-icloud-documents/ · 2023-07-20 https://eclecticlight.co/2023/07/20/backing-up-icloud-icloud-recovery-and-document-versions/ · 2023-10-25 https://eclecticlight.co/2023/10/25/macos-sonoma-has-changed-icloud-drive-radically/ · 2023-10-30 https://eclecticlight.co/2023/10/30/how-macos-sonoma-has-changed-icloud-even-more/ · 2023-11-21 https://eclecticlight.co/2023/11/21/icloud-drive-in-sonoma-fileprovider-and-eviction/ · 2024-03-11 https://eclecticlight.co/2024/03/11/icloud-drive-in-sonoma-optimise-mac-storage-or-not/ · 2024-03-18 https://eclecticlight.co/2024/03/18/how-icloud-drive-works-in-macos-sonoma/ · 2024-09-16 https://eclecticlight.co/2024/09/16/sequoia-introduces-pinning-to-icloud-drive/ · 2024-09-30 https://eclecticlight.co/2024/09/30/how-icloud-has-changed-in-sequoia-pinning-and-more/ · 2024-10-02 https://eclecticlight.co/2024/10/02/pinning-icloud-drive-in-sequoia-is-bizarre-and-an-update-to-cirrus/ · 2026-04-06 https://eclecticlight.co/2026/04/06/understanding-and-testing-icloud/ · 2026-05-12 https://eclecticlight.co/2026/05/12/what-gets-synced-in-icloud-drive/ · 2026-08-25 https://eclecticlight.co/2026/08/25/an-icloud-primer/ · 2026-08-28 https://eclecticlight.co/2026/08/28/golden-gate-and-forthcoming-updates/
- Michael Tsai: 2023-05-11 https://mjtsai.com/blog/2023/05/11/getting-ready-for-dataless-files/ · 2023-10-27 https://mjtsai.com/blog/2023/10/27/icloud-drive-switches-to-dataless-files/ · 2024-10-02 https://mjtsai.com/blog/2024/10/02/pinning-icloud-drive-in-sequoia/
- icanhasjonas/icloud-tools — https://github.com/icanhasjonas/icloud-tools (Foundation-only download/evict/pin; its "brctl gone" note is stale for 26.4.1)
- Apple Community 255925937 — works in Terminal, `Resource deadlock avoided` from a launchd agent — https://discussions.apple.com/thread/255925937
- RsyncProject/rsync #522 — https://github.com/RsyncProject/rsync/issues/522 · bexelbie 2023-09-05 — https://bexelbie.com/technology/2023/09/05/rsync-icloud · Jesse Squires 2019-09-27 — https://www.jessesquires.com/blog/2019/09/27/icloud-backup-using-rsync/
- anthropics/claude-code #40783 — https://github.com/anthropics/claude-code/issues/40783 · lima-vm/lima #4123 — https://github.com/lima-vm/lima/issues/4123 · restic #5352 — https://github.com/restic/restic/issues/5352 · rdiff-backup #1027 — https://github.com/rdiff-backup/rdiff-backup/issues/1027 · fish-shell #8399 — https://github.com/fish-shell/fish-shell/issues/8399 · Duplicacy forum — https://forum.duplicacy.com/t/macos-resource-deadlock-avoided/7289 · Noodlesoft (Hazel) — https://www.noodlesoft.com/forums/viewtopic.php?f=4&t=17138 · Qiita — https://www.qiita.com/bokuwalily/items/94807b86e46cb8393399 · `.nosync` — https://discussions.apple.com/thread/255183704
- macOS 27 beta issues tracker — https://github.com/jizhi0v0/macos27-beta-issues

## Backup vendors

- Bombich (Carbon Copy Cloner), 2026-07-28 — https://bombich.com/blog/2026/07/28/local-backups-of-cloud-storage ; KB — https://bombich.com/en/kb/ccc/6/limitations-online-only-placeholder-files
- Arq 7 dataless files — https://www.arqbackup.com/documentation/arq7/English.lproj/datalessFiles.html ; blog — https://www.arqbackup.com/blog/backing-up-cloud-only-files-with-arq/ ; release notes — https://www.arqbackup.com/download/arqbackup/arq7_release_notes.html
- ChronoSync, File Provider quirks — https://www.econtechnologies.com/chronosync/tn-cs-file-provider-quirks.html ; iCloud backup guide — https://www.econtechnologies.com/chronosync/guide-backup-icloud-storage.html
