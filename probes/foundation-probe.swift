import Foundation
let path = CommandLine.arguments[1]; let mode = CommandLine.arguments[2]  // "off" or "on"
let T: Int32 = 3; setiopolicy_np(T, IOPOL_SCOPE_PROCESS, mode == "off" ? 1 : 2)
print("policy:", getiopolicy_np(T, IOPOL_SCOPE_PROCESS) == 1 ? "OFF" : "ON")
let url = URL(fileURLWithPath: path)
func dl() -> Bool { var st = stat(); stat(path, &st); return (st.st_flags & UInt32(SF_DATALESS)) != 0 }
let rv = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .fileSizeKey, .totalFileAllocatedSizeKey])
print("isUbiquitousItem:", rv?.isUbiquitousItem as Any, "| status:", rv?.ubiquitousItemDownloadingStatus?.rawValue ?? "nil", "| size:", rv?.fileSize ?? -1, "| allocated:", rv?.totalFileAllocatedSize ?? -1, "| dataless:", dl())
func err(_ e: Error) -> String { let n = e as NSError; let u = (n.userInfo[NSUnderlyingErrorKey] as? NSError).map { " underlying=\($0.domain)/\($0.code)" } ?? ""; return "\(n.domain)/\(n.code)\(u) '\(n.localizedDescription)'" }
var t = Date()
do { let d = try Data(contentsOf: url); print("Data(contentsOf:) OK \(d.count) bytes in \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())") }
catch { print("Data(contentsOf:) FAILED \(err(error)) in \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())") }
let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dataless-probe-\(getpid())"); t = Date()
do { try FileManager.default.copyItem(at: url, to: dst); let a = try FileManager.default.attributesOfItem(atPath: dst.path); print("copyItem OK size=\(a[.size] ?? "?") in \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())") }
catch { print("copyItem FAILED \(err(error)) in \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())") }
try? FileManager.default.removeItem(at: dst)
if mode == "off" && dl() {
    t = Date(); var ok = false; _ = ok
    do { try FileManager.default.startDownloadingUbiquitousItem(at: url); ok = true; print("startDownloadingUbiquitousItem returned in \(String(format: "%.3f", Date().timeIntervalSince(t)))s (no error) | dataless immediately after: \(dl())") } catch { print("startDownloadingUbiquitousItem FAILED \(err(error))") }
    for i in 0..<40 { if !dl() { print("  -> materialised after ~\(i*250) ms of polling"); break }; usleep(250_000) }
    if dl() { print("  -> still dataless after 10 s of polling") }
}
if mode == "off" && dl() {
    t = Date(); var ce: NSError?; var inner = "not run"
    NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &ce) { u in do { let d = try Data(contentsOf: u); inner = "read OK \(d.count) bytes" } catch { inner = "read FAILED \(err(error))" } }
    print("NSFileCoordinator read: coordError=\(ce.map { "\($0.domain)/\($0.code)" } ?? "nil") accessor: \(inner) in \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())")
}
