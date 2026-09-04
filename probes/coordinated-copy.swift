import Foundation
let path = CommandLine.arguments[1]
setiopolicy_np(3, IOPOL_SCOPE_PROCESS, 1)   // materialisation OFF for this process
func dl() -> Bool { var st = stat(); stat(path, &st); return (st.st_flags & UInt32(SF_DATALESS)) != 0 }
let url = URL(fileURLWithPath: path); let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dataless-coord-\(getpid())")
print("policy:", getiopolicy_np(3, IOPOL_SCOPE_PROCESS) == 1 ? "OFF" : "ON", "| dataless before:", dl())
let t = Date(); var ce: NSError?; var inner = "not run"
NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &ce) { u in
    let insideDataless = dl()
    do { try FileManager.default.copyItem(at: u, to: dst); let a = try FileManager.default.attributesOfItem(atPath: dst.path); inner = "copyItem OK size=\(a[.size] ?? "?") (dataless when accessor ran: \(insideDataless))" }
    catch { let n = error as NSError; inner = "copyItem FAILED \(n.domain)/\(n.code) underlying=\((n.userInfo[NSUnderlyingErrorKey] as? NSError).map{"\($0.domain)/\($0.code)"} ?? "-") (dataless when accessor ran: \(insideDataless))" }
}
print("coordinated copy: coordError=\(ce.map{"\($0.domain)/\($0.code)"} ?? "nil") | \(inner) | \(String(format: "%.3f", Date().timeIntervalSince(t)))s | dataless after: \(dl())")
try? FileManager.default.removeItem(at: dst)
