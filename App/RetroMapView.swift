import SwiftUI

struct RetroMapView: View {
  var location: ScanLocation
  var name: String
  @State private var model = RetroMapModel()
  @State private var zoom = -1
  @State private var retry = 0

  var body: some View {
    GeometryReader { geometry in
      let size = CGSize(width: max(1, geometry.size.width), height: max(1, geometry.size.height))
      ZStack {
        Color(red: 0.42, green: 0.74, blue: 0.57)
        if let image = model.image {
          Image(uiImage: image)
            .resizable()
            .interpolation(.none)
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(true)
          Circle()
            .fill(Color(red: 0.68, green: 0.18, blue: 0.22).opacity(0.12))
            .overlay(Circle().strokeBorder(Color(red: 0.55, green: 0.14, blue: 0.19), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .frame(width: max(6, model.accuracyRadius * 2), height: max(6, model.accuracyRadius * 2))
            .position(model.pin)
            .accessibilityHidden(true)
          Canvas { context, canvasSize in
            // An original, square-pixel location beacon; its tip is the coordinate.
            let rows = ["..####..", ".######.", "##....##", "##.##.##", "##.##.##", ".######.", "..####..", "...##..."]
            for (y, row) in rows.enumerated() {
              for (x, character) in row.enumerated() where character == "#" {
                context.fill(Path(CGRect(x: x * 3, y: y * 3, width: 3, height: 3)), with: .color(Color(red: 0.72, green: 0.18, blue: 0.23)))
              }
            }
          }
          .frame(width: 24, height: 24)
          .background(.white.opacity(0.85), in: Rectangle())
          .position(x: model.pin.x, y: model.pin.y - 12)
          .accessibilityLabel("Saved location of \(name)")
        }
        if model.loading {
          ProgressView("Drawing map…")
            .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else if model.failed {
          VStack(spacing: 12) {
            Text("Couldn’t load the map").font(.headline)
            Text("Check your connection and try again, or switch to Standard.")
              .multilineTextAlignment(.center)
            Button("Try Again", systemImage: "arrow.clockwise") { retry += 1 }
              .buttonStyle(.borderedProminent)
          }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding()
        }
      }
      .clipped()
      .overlay(alignment: .topTrailing) {
        HStack(spacing: 0) {
          Button("Zoom out", systemImage: "minus") { zoom += 1 }
            .disabled(zoom >= 7)
          Button("Zoom in", systemImage: "plus") { zoom -= 1 }
            .disabled(zoom <= -1)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color(red: 0.22, green: 0.34, blue: 0.30))
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(12)
      }
      .task(id: SnapshotRequest(width: size.width, height: size.height, zoom: zoom, retry: retry)) {
        // Coalesce resize and repeated zoom requests before fetching map tiles.
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
        await model.load(location: location, size: size, zoom: zoom)
      }
    }
  }
}

private struct SnapshotRequest: Hashable {
  var width: CGFloat
  var height: CGFloat
  var zoom: Int
  var retry: Int
}
