import Foundation

/// Debug-only stage timings; no photos, keys, or identification content are logged.
enum CaptureTiming {
  private static let lock = NSLock()
  private static var events: [(String, TimeInterval)] = []

  static func mark(_ stage: String) {
    #if DEBUG
    let time = ProcessInfo.processInfo.systemUptime
    lock.lock()
    if stage == "shutter tapped" { events.removeAll() }
    events.append((stage, time))
    if events.count > 30 { events.removeFirst() }
    lock.unlock()
    print("CaptureTiming \(time): \(stage)")
    #endif
  }

  static var report: String {
    lock.lock()
    defer { lock.unlock() }
    guard let first = events.first else { return "Take a photo to record capture timings." }
    return events.map { stage, time in
      "\(Int((time - first.1) * 1000)) ms — \(stage)"
    }.joined(separator: "\n")
  }
}
