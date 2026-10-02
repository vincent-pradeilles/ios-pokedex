import SwiftUI

/// Uses the physical fold in this view's coordinates, including when flat.
/// Safe-area asymmetry must never shift the replica's hinge off the device fold.
@available(iOS 27.1, *)
struct DuoHardwareLayout<Left: View, Right: View>: View {
  @ViewBuilder var left: () -> Left
  @ViewBuilder var right: () -> Right

  var body: some View {
    GeometryReader { geometry in
      let division = geometry.reservedRegions(kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed).first
      let fold = division?.frame
      let horizontal = fold.map { $0.width > $0.height } ?? false
      let extent = horizontal ? geometry.size.height : geometry.size.width
      let center = min(extent, max(0, fold.map { horizontal ? $0.midY : $0.midX } ?? extent / 2))
      let gap = max(20, fold.map { horizontal ? $0.height : $0.width } ?? 0)
      let first = max(0, center - gap / 2)
      let second = max(0, extent - center - gap / 2)

      ZStack(alignment: .topLeading) {
        if horizontal {
          left().frame(width: geometry.size.width, height: first)
          right().frame(width: geometry.size.width, height: second)
            .offset(y: center + gap / 2)
          HingeSpine().frame(width: gap, height: geometry.size.width)
            .rotationEffect(.degrees(90))
            .position(x: geometry.size.width / 2, y: center)
        } else {
          left().frame(width: first, height: geometry.size.height)
          right().frame(width: second, height: geometry.size.height)
            .offset(x: center + gap / 2)
          HingeSpine().frame(width: gap, height: geometry.size.height)
            .position(x: center, y: geometry.size.height / 2)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(DexTheme.shell)
      .clipped()
    }
  }
}

struct ImmersiveHardwarePresentation: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.toolbarVerticalBehavior(.disabled)
        .toolbarVisibility(.hidden, for: .navigationBar)
    } else {
      content.toolbarVisibility(.hidden, for: .navigationBar)
    }
  }
}
