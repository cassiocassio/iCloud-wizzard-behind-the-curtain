// Count how many files iCloud has actually uploaded.
//
// WHY THIS EXISTS. `brctl` reports the whole container as caught-up or not — a
// boolean. NSMetadataQuery returns nothing for an arbitrary iCloud Drive path
// because it only covers an app's own ubiquity container. mdls exposes no ubiquity
// attributes, and `fileproviderctl dump` carries an NSProgress with no counts.
// URLResourceValues is the one API that answers per file, with no container.
//
// PACKAGES ARE ONE ITEM, AND THAT IS THE WHOLE CORRECTNESS STORY HERE.
//
// iCloud tracks a package bundle (.app, .xcodeproj, .framework, .bbprojectd, and
// Xcode 26's .icon) as a SINGLE ubiquitous item. Its internal files are not
// individually tracked, so `ubiquitousItemIsUploaded` returns **nil** for them —
// not false. The package DIRECTORY answers true/false correctly.
//
// The first version of this file counted nil as pending, with a comment arguing it
// was the safe choice: "never round toward your data is safe". That reasoning is
// right for a plain file and wrong for a package internal, and the cost was a
// permanent, un-clearable false alarm sized to however many bundles the tree holds
// — 122 files reported as "never uploaded", some supposedly for four months, on a
// mirror that was in fact 100% uploaded (measured 30 Aug 2026: 39,811 true, 122
// nil, 0 false — and all 122 nils were package internals).
//
// Proven by byte-level round trip, not by trusting the flag: a package of random
// incompressible bytes was evicted until `du -sk` read 0 KB, then read back
// byte-identical by sha256. The bytes were genuinely in the cloud the whole time.
//
// The same nil is what makes `brctl evict` crash on a file inside a package
// (NSInvalidArgumentException, nil into an array); evicting the package DIRECTORY
// works fine.
//
// So: never ask about a file inside a package. Ask about the package.
//
// WHY A CUTOFF / WHY PATHS ON STDIN. A full scan runs at roughly 600 files/sec —
// minutes for a large mirror, too slow to poll. Callers narrow the set: offsite-watch
// pipes `find -cnewer <marker>` (this run's files only), and measure-mirror uses
// --walk for the whole-mirror figure.
//
// WHY IT IS A SEPARATE BINARY. Reading iCloud Drive needs the TCC grant. Run from
// the backup scripts it inherits the applet's; the menubar app never calls it and
// so never needs a grant of its own. That separation is the whole architecture.
//
// Usage:
//   find <dir> -type f | icloud-status [--budget N]     paths on stdin
//   icloud-status --walk <root> [--budget N]            enumerate, packages as units

import Foundation

let keys: Set<URLResourceKey> = [
    .isUbiquitousItemKey, .ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey,
]

var uploaded = 0, pending = 0, uploading = 0, unknown = 0, seen = 0, notApplicable = 0
var truncated = false

var budget: TimeInterval = 20
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--budget"), i + 1 < args.count, let b = Double(args[i + 1]) { budget = b }
let deadline = Date().addingTimeInterval(budget)

var walkRoot: String? = nil
if let i = args.firstIndex(of: "--walk"), i + 1 < args.count { walkRoot = args[i + 1] }

/// Is this URL a file package? Authoritative, and deliberately NOT an extension
/// allow-list: a hardcoded list of .app/.xcodeproj/.framework misses .bbprojectd
/// (BBEdit) and .icon (Xcode 26 Icon Composer), and misclassifying those as loose
/// files that failed to upload is the exact false positive this rewrite removes.
func isPackage(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
}

/// Walk up from a file to see whether any ancestor is a package. Memoised, because
/// a deep bundle asks the same question about the same parents thousands of times.
var packageCache: [String: Bool] = [:]
func hasPackageAncestor(_ url: URL, stopAt root: String?) -> Bool {
    var dir = url.deletingLastPathComponent()
    var chain: [String] = []
    while dir.path != "/" && dir.path.count > 1 {
        if let cached = packageCache[dir.path] {
            for c in chain { packageCache[c] = cached }
            return cached
        }
        if isPackage(dir) {
            for c in chain { packageCache[c] = true }
            packageCache[dir.path] = true
            return true
        }
        chain.append(dir.path)
        if let root, dir.path == root { break }
        dir = dir.deletingLastPathComponent()
    }
    for c in chain { packageCache[c] = false }
    return false
}

/// Classify one item that we have already decided IS the right thing to ask about.
func classify(_ url: URL) {
    seen += 1
    guard let v = try? url.resourceValues(forKeys: keys), v.isUbiquitousItem == true else {
        unknown += 1; return
    }
    if v.ubiquitousItemIsUploading == true { uploading += 1 }
    switch v.ubiquitousItemIsUploaded {
    case .some(true):  uploaded += 1
    case .some(false): pending += 1
    case nil:
        // Unknown on something we believe IS an individually-tracked item. Keep the
        // original conservative rule for exactly this case — it must not round
        // toward "safe" — while package internals never reach here at all.
        pending += 1; unknown += 1
    }
}

if let root = walkRoot {
    // Whole-tree mode. Packages are counted as ONE item and not descended into,
    // which is what iCloud itself does.
    let rootURL = URL(fileURLWithPath: root)
    if let e = FileManager.default.enumerator(
        at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isRegularFileKey],
        options: [], errorHandler: { _, _ in true }) {
        while let u = e.nextObject() as? URL {
            if Date() > deadline { truncated = true; break }
            let rv = try? u.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isRegularFileKey])
            if rv?.isPackage == true {
                classify(u)            // the package IS the item
                e.skipDescendants()    // never ask about its internals
                continue
            }
            if rv?.isDirectory == true { continue }
            guard rv?.isRegularFile == true else { continue }
            let name = u.lastPathComponent
            if name.hasPrefix("._") || name == ".DS_Store" { continue }   // OS metadata
            classify(u)
        }
    }
} else {
    // stdin mode. A caller's `find` descends into packages, so filter here: a file
    // with a package ancestor is not an individually-tracked item and must be
    // excluded from BOTH numerator and denominator rather than counted pending.
    while let line = readLine(strippingNewline: true) {
        if line.isEmpty { continue }
        if Date() > deadline { truncated = true; break }
        let url = URL(fileURLWithPath: line)
        if hasPackageAncestor(url, stopAt: nil) { notApplicable += 1; continue }
        classify(url)
    }
}

// total counts only items iCloud actually reports on, so a mirror whose every
// reportable item is up reads 100% — which is the truth.
let total = uploaded + pending
print("""
{"seen":\(seen),"uploaded":\(uploaded),"pending":\(pending),"uploading":\(uploading),\
"unknown":\(unknown),"notApplicable":\(notApplicable),"total":\(total),"truncated":\(truncated)}
""")
