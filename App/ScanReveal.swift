import SwiftUI

/// The original and transparent cutout share the same image bounds. Removing the
/// original reveals the screen through the cutout's alpha while inference runs.
struct ScanReveal: View {
  var original: UIImage?
  var cutout: UIImage?
  var removing: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var sweep = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        if let cutout {
          Image(uiImage: cutout).resizable().scaledToFit()
        }
        if let original {
          Image(uiImage: original).resizable().scaledToFit()
            .opacity(cutout == nil ? 1 : 0)
            .animation(.easeOut(duration: reduceMotion ? 0.2 : 0.85), value: cutout != nil)
        }
        if removing {
          if !reduceMotion {
            LinearGradient(colors: [.clear, .white.opacity(0.08), .white.opacity(0.65), .cyan.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)
              .frame(width: proxy.size.width * 0.7)
              .rotationEffect(.degrees(15))
              .offset(x: sweep ? proxy.size.width : -proxy.size.width)
              .blendMode(.screen)
              .onAppear {
                sweep = false
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { sweep = true }
              }
          }
          VStack {
            Spacer()
            Label("Preparing cutout…", systemImage: "viewfinder")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .padding(7).foregroundStyle(.white)
              .background(.black.opacity(0.65), in: Capsule())
          }.padding(8)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .scaleEffect(cutout == nil ? 1 : 0.98)
      .offset(y: cutout == nil ? -4 : 0)
      .animation(reduceMotion ? nil : .spring(duration: 1.05, bounce: 0.13), value: cutout != nil)
      .clipped()
    }
    .accessibilityLabel(removing ? "Removing background" : "Background removed; Pokémon displayed")
  }
}
