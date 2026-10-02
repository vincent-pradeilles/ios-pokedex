import SwiftUI
import PhotosUI

struct HardwareFit<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    GeometryReader { proxy in
      content()
        .frame(width: 340, height: 700)
        .scaleEffect(min(proxy.size.width / 340, proxy.size.height / 700))
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}

struct LeftHardwarePanel: View {
  var model: DexModel
  @Binding var photo: PhotosPickerItem?
  var camera: () -> Void
  var journal: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ReplicaSensor()
      VStack(spacing: 16) {
        DisplayPanel(entry: model.entry, image: model.cutout, originalPhoto: model.originalPhoto, busy: model.busy, phase: model.phase)
        HStack(spacing: 13) {
          Button(action: camera) {
            Circle().fill(Color(white: 0.10).gradient).frame(width: 42, height: 42)
              .overlay(Circle().stroke(.black, lineWidth: 3))
              .overlay(Image(systemName: "camera.fill").font(.system(size: 15)).foregroundStyle(.white.opacity(0.65)))
          }.accessibilityLabel("Take a Pokémon photo").disabled(model.busy)
          Capsule().fill(Color(red: 0.97, green: 0.28, blue: 0.20)).frame(width: 47, height: 9).overlay(Capsule().stroke(.black.opacity(0.65), lineWidth: 2))
          Capsule().fill(DexTheme.lime).frame(width: 47, height: 9).overlay(Capsule().stroke(.black.opacity(0.65), lineWidth: 2))
          Spacer()
        }
        HStack(alignment: .center, spacing: 20) {
          VStack(alignment: .leading, spacing: 6) {
            Text(model.busy ? "SCANNING…" : "POKÉDEX READY")
            Text("FOUND  \(model.history.count.formatted(.number.precision(.integerLength(3))))")
            Text(model.entry.isSample ? "DEMO / No. 025" : "LOCAL AI MATCH")
          }.font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(red: 0.18, green: 0.30, blue: 0.07))
            .frame(width: 138, height: 65, alignment: .leading).padding(.leading, 12)
            .background(DexTheme.lime.gradient, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.4), lineWidth: 2))
          Spacer(minLength: 0)
          Button(action: journal) { DPad() }.accessibilityLabel("Open field journal")
        }
      }.padding(.horizontal, 23).padding(.top, 14)
      Spacer(minLength: 0)
      HStack {
        PhotosPicker(selection: $photo, matching: .images) {
          Label("PHOTO", systemImage: "photo").font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(10).background(.black.opacity(0.1), in: Capsule())
        }.disabled(model.busy)
        Spacer()
        if model.busy {
          Button("Cancel") { model.cancel() }.font(.caption)
        } else {
          Text("KANTO • FIELD UNIT 01").font(.system(size: 8, design: .monospaced)).tracking(1)
        }
      }.foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 24).padding(.bottom, 12)
    }
    .background(DexTheme.shell, in: RoundedRectangle(cornerRadius: 22))
    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black.opacity(0.38), lineWidth: 3))
    .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.13)).padding(6).allowsHitTesting(false))
  }
}

struct RightHardwarePanel: View {
  var model: DexModel
  var settings: () -> Void
  var journal: () -> Void
  @State private var notes = false
  var body: some View {
    VStack(spacing: 0) {
      Color.clear.frame(height: 112)
      VStack(alignment: .leading, spacing: 23) {
        Button { notes = true } label: {
          VStack(alignment: .leading, spacing: 9) {
            Text(model.entry.name.uppercased()).font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(model.entry.summary).font(.system(size: 15, weight: .medium, design: .monospaced)).lineSpacing(3)
              .lineLimit(7)
            Spacer(minLength: 0)
            Text(model.entry.isSample ? "SAMPLE ENTRY" : "ON-DEVICE AI • TAP FOR DETAILS")
              .font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
          }.foregroundStyle(Color(white: 0.91)).padding(16)
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 188)
            .background(Color(red: 0.025, green: 0.045, blue: 0.047).gradient, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black, lineWidth: 3))
        }.buttonStyle(.plain).accessibilityLabel("Read full entry for \(model.entry.name)")
        VStack(spacing: 3) {
          ForEach(0..<2) { row in
            HStack(spacing: 3) {
              ForEach(0..<5) { column in
                Button { notes = true } label: {
                  RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.70, blue: 0.95), Color(red: 0.12, green: 0.42, blue: 0.74)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.65)))
                    .frame(height: 34)
                }.accessibilityLabel("Entry details, key \(row * 5 + column + 1)")
              }
            }
          }
        }.padding(3).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
        HStack(alignment: .top) {
          HStack(spacing: 2) {
            Button(action: journal) { hardwareKey("book.closed.fill") }.accessibilityLabel("Field journal")
            Button(action: settings) { hardwareKey("gearshape") }.accessibilityLabel("Settings")
          }
          Spacer()
          VStack(spacing: 13) {
            HStack(spacing: 6) {
              Capsule().fill(.red.gradient).frame(width: 29, height: 7)
              Capsule().fill(DexTheme.lime.gradient).frame(width: 29, height: 7)
            }.overlay(Capsule().stroke(.black.opacity(0.3)))
            Button(action: settings) {
              Circle().fill(Color(red: 0.98, green: 0.78, blue: 0.12).gradient)
                .frame(width: 33, height: 33).overlay(Circle().stroke(.black.opacity(0.65), lineWidth: 2))
            }.accessibilityLabel("Configure Pokédex")
          }
        }
        HStack(spacing: 28) {
          Text(model.entry.type.uppercased()).frame(maxWidth: .infinity)
          Text(String(format: "No. %03d", model.entry.number)).frame(maxWidth: .infinity)
        }.font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
          .padding(.vertical, 12)
          .background(Color(white: 0.035), in: RoundedRectangle(cornerRadius: 4))
      }.padding(.horizontal, 29)
      Spacer(minLength: 0)
    }
    .background(DexTheme.shell, in: RightShell())
    .overlay(RightShell().stroke(.black.opacity(0.4), lineWidth: 3))
    .sheet(isPresented: $notes) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text(model.entry.type).font(.headline).foregroundStyle(.secondary)
            Text(model.entry.summary).font(.title3)
            Text(model.entry.isSample ? "Sample entry" : "Generated on device. AI identification and notes can be inaccurate.").font(.footnote).foregroundStyle(.secondary)
          }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.navigationTitle(model.entry.name)
          .toolbar { Button("Done", systemImage: "checkmark") { notes = false } }
      }
    }
  }
  private func hardwareKey(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(.black.opacity(0.55))
      .frame(width: 38, height: 38).background(Color(white: 0.90).gradient, in: RoundedRectangle(cornerRadius: 2))
      .overlay(RoundedRectangle(cornerRadius: 2).stroke(.black.opacity(0.6)))
  }
}

private struct DPad: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4).frame(width: 27, height: 79)
      RoundedRectangle(cornerRadius: 4).frame(width: 79, height: 27)
      Circle().fill(Color(white: 0.09)).frame(width: 21, height: 21)
        .overlay(Circle().stroke(.white.opacity(0.06)))
    }.foregroundStyle(Color(white: 0.045).gradient)
      .shadow(color: .black, radius: 1, y: 3)
      .shadow(color: .white.opacity(0.25), radius: 1, x: -1, y: -1)
      .frame(width: 79, height: 79)
  }
}

private struct RightShell: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: 0, y: 35))
      p.addLine(to: CGPoint(x: 72, y: 35))
      p.addCurve(to: CGPoint(x: 200, y: 99), control1: CGPoint(x: 115, y: 35), control2: CGPoint(x: 117, y: 99))
      p.addLine(to: CGPoint(x: r.maxX - 16, y: 99))
      p.addQuadCurve(to: CGPoint(x: r.maxX, y: 115), control: CGPoint(x: r.maxX, y: 99))
      p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 18))
      p.addQuadCurve(to: CGPoint(x: r.maxX - 18, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
      p.addLine(to: CGPoint(x: 0, y: r.maxY))
      p.closeSubpath()
    }
  }
}
