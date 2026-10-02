import SwiftUI

struct DisplayPanel: View {
  var entry: DexEntry
  var image: UIImage?
  var originalPhoto: UIImage?
  var subjectBounds: CGRect
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var busy: Bool
  var phase: String

  private var isEmpty: Bool { entry.number == 0 && originalPhoto == nil && image == nil && !busy }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        Circle().fill(DexTheme.red).frame(width: 5, height: 5)
        Circle().fill(DexTheme.red).frame(width: 5, height: 5)
      }.accessibilityHidden(true)
      VStack(spacing: 8) {
        HStack {
          Text(entry.number > 0 ? String(format: "No. %03d", entry.number) : "No. ———")
          Spacer()
          Text(busy ? "SCANNING" : isEmpty ? "AWAITING SCAN" : entry.number > 0 ? "AI MATCH" : "NO MATCH")
        }.font(.system(.caption2, design: .monospaced, weight: .medium))
        ZStack {
          GridPattern().stroke(DexTheme.ink.opacity(0.065), lineWidth: 0.5)
          if originalPhoto != nil || image != nil {
            ScanReveal(original: originalPhoto, cutout: image, subjectBounds: subjectBounds, removing: busy && image == nil)
          } else {
            Image(systemName: "viewfinder").font(.system(size: 75)).opacity(0.4)
          }
        }.frame(height: 225)
        HStack(alignment: .firstTextBaseline) {
          Text(entry.name).font(.system(.title2, design: .rounded, weight: .heavy))
          Spacer()
          Text(entry.type.uppercased()).font(.system(.caption2, design: .monospaced, weight: .bold))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(DexTheme.ink.opacity(0.08), in: Capsule())
        }
      }
      .foregroundStyle(DexTheme.ink)
      .padding(7)
      .background(Color(red: 0.80, green: 0.87, blue: 0.79))
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(white: 0.09), lineWidth: 6))
      HStack {
        Circle().fill(DexTheme.red.gradient).frame(width: 18, height: 18)
          .overlay(Circle().stroke(.black.opacity(0.3)))
        Spacer()
        Text("\(busy ? "PROCESSING" : "\u{25CF}  " + phase.uppercased())")
          .font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(DexTheme.ink.opacity(0.65))
      }.padding(.horizontal, 8).padding(.top, 2)
    }
    .padding(15)
    .background(LinearGradient(colors: [Color(white: 0.94), Color(white: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
    .shadow(color: .black.opacity(0.35), radius: 1, y: 5)
  }
}

private struct GridPattern: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      for x in stride(from: 0.0, through: rect.width, by: 18) {
        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
      }
      for y in stride(from: 0.0, through: rect.height, by: 18) {
        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y))
      }
    }
  }
}
