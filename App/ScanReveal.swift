import SwiftUI

/// Both images share one canvas and one transform, so the subject remains
/// registered throughout the background dissolve and move into the display.
struct ScanReveal: View {
  var original: UIImage?
  var cutout: UIImage?
  var subjectBounds: CGRect
  var artificialShadow: Bool
  var removing: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: CGFloat = 0

  var body: some View {
    GeometryReader { proxy in
      let sourceSize = original?.size ?? cutout?.size ?? CGSize(width: 1, height: 1)
      let fit = min(proxy.size.width / max(1, sourceSize.width), proxy.size.height / max(1, sourceSize.height))
      let width = sourceSize.width * fit
      let height = sourceSize.height * fit
      // Fit all visible pixels, including the AI shadow, with a small safe inset.
      let targetScale = min(max(1, proxy.size.width - 24) / max(1, width * subjectBounds.width),
                            max(1, proxy.size.height - 24) / max(1, height * subjectBounds.height))
      let movement = reduceMotion ? (cutout == nil ? CGFloat(0) : 1) : progress
      let scale = 1 + (targetScale - 1) * movement

      ZStack {
        if artificialShadow && cutout != nil {
          Ellipse()
            .fill(Color.black.opacity(0.14))
            .frame(width: width * subjectBounds.width * 0.72,
                   height: max(2, height * subjectBounds.height * 0.07))
            .blur(radius: 2 / max(1, targetScale))
            .position(x: width * subjectBounds.midX,
                      y: height * subjectBounds.maxY - height * subjectBounds.height * 0.025)
            .opacity(progress)
            .accessibilityHidden(true)
        }
        if let cutout {
          Image(uiImage: cutout).resizable().scaledToFit()
            .frame(width: width, height: height)
            .transition(.identity)
        }
        if let original {
          Image(uiImage: original).resizable().scaledToFit()
            .frame(width: width, height: height)
            .overlay {
              if removing && !reduceMotion {
                PhotoShimmer().allowsHitTesting(false)
              }
            }
            // Clip the shimmer to the photo's actual fitted rectangle, not the LCD.
            .clipped()
            .opacity(1 - progress)
        }
      }
      .frame(width: width, height: height)
      .scaleEffect(scale)
      .offset(x: (0.5 - subjectBounds.midX) * width * targetScale * movement,
              y: (0.5 - subjectBounds.midY) * height * targetScale * movement)
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipped()
    }
    .task(id: cutout != nil) {
      guard cutout != nil else {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = 0 }
        return
      }
      guard original != nil else {
        progress = 1
        return
      }
      // Insert the transparent image at the original transform before changing
      // the shared transform. Identification is already running independently.
      await Task.yield()
      guard !Task.isCancelled else { return }
      withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 1.25, bounce: 0)) {
        progress = 1
      }
    }
    .accessibilityLabel(removing ? "Removing background" : "Background removed; Pokémon displayed")
  }
}

private struct PhotoShimmer: View {
  @State private var sweep = false

  var body: some View {
    GeometryReader { geometry in
      LinearGradient(colors: [.clear, .white.opacity(0.08), .white.opacity(0.6), .cyan.opacity(0.2), .clear],
                     startPoint: .leading, endPoint: .trailing)
        .frame(width: geometry.size.width * 0.65, height: geometry.size.height * 1.5)
        .rotationEffect(.degrees(15))
        .position(x: sweep ? geometry.size.width * 1.5 : -geometry.size.width * 0.5,
                  y: geometry.size.height / 2)
        .blendMode(.screen)
        .onAppear {
          withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
    .clipped()
    .accessibilityHidden(true)
  }
}
