import Foundation
for p in CommandLine.arguments.dropFirst() { let u = URL(fileURLWithPath: p); var st = stat(); do { try FileManager.default.evictUbiquitousItem(at: u); usleep(500_000); stat(p, &st); print("evict OK -> dataless now:", (st.st_flags & UInt32(SF_DATALESS)) != 0) } catch { let n = error as NSError; print("evict FAILED \(n.domain)/\(n.code) '\(n.localizedDescription)'") } }
