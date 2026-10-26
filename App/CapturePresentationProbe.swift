#if DEBUG
import SwiftUI

/// Records display-link progress after SwiftUI inserts the captured still.
/// This is a UI-thread responsiveness marker, not a hardware display measurement.
struct CapturePresentationProbe: UIViewRepresentable {
  func makeUIView(context: Context) -> CapturePresentationView { CapturePresentationView() }
  func updateUIView(_ view: CapturePresentationView, context: Context) { }
  static func dismantleUIView(_ view: CapturePresentationView, coordinator: ()) { view.stop() }
}

final class CapturePresentationView: UIView {
  private var displayLink: CADisplayLink?
  private var ticks = 0

  override func didMoveToWindow() {
    super.didMoveToWindow()
    stop()
    guard window != nil else { return }
    CaptureTiming.mark("still view inserted")
    ticks = 0
    let link = CADisplayLink(target: self, selector: #selector(refresh))
    displayLink = link
    link.add(to: .main, forMode: .common)
  }

  @objc private func refresh() {
    ticks += 1
    if ticks == 2 {
      CaptureTiming.mark("UI display refresh after still")
      stop()
    }
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
  }
}
#endif
