# Probes

Small, single-purpose, and deliberately boring. Each one prints what it did and
re-`stat`s the file afterwards so you can see whether the bytes came down.

**Pick a target you can afford to materialise** — a placeholder under 1 KB — and
put it back with `evict.swift` (or `brctl evict <path>`) when you are done. Find one:

```bash
find "$HOME/Library/Mobile Documents/com~apple~CloudDocs" -type f -print0 \
  | xargs -0 stat -f '%Sf|%z|%N' | grep dataless | awk -F'|' '$2>0 && $2<1024 {print $3; exit}'
```

| probe | what it answers | build / run |
|---|---|---|
| `policy-probe.swift` | what materialisation policy is *this* process running under? | `swiftc -O policy-probe.swift -o pol && ./pol` — then `launchctl submit -l x.pol -o /tmp/pol.out -- $PWD/pol; sleep 2; cat /tmp/pol.out; launchctl remove x.pol` |
| `ops-probe.c` | which syscalls fail on a placeholder, under which policy | `cc -o ops ops-probe.c && ./ops <file> [mode]` — modes: 0 default, 1 force ON, 2 force OFF, 3 clonefile, 4 mmap only, 5 clonefile under OFF, 6 copyfile under OFF |
| `foundation-probe.swift` | `Data(contentsOf:)`, `copyItem`, `startDownloadingUbiquitousItem`, coordinated read | `swiftc -O foundation-probe.swift -o fp && ./fp <file> off` (or `on`) |
| `coordinated-copy.swift` | does `NSFileCoordinator` materialise for a `copyItem` under policy OFF? | `swiftc -O coordinated-copy.swift -o fc && ./fc <file>` |
| `evict.swift` | put a file back to dataless | `swiftc -O evict.swift -o ev && ./ev <file>…` |

`swiftc` needs Xcode or the Command Line Tools. Every probe was run on
macOS 26.4.1; the results are in [`../results/`](../results/).
