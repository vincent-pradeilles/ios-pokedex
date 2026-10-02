import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
  @State private var model = DexModel()
  @State private var settings = false
  @State private var journal = false
  @State private var camera = false
  @State private var photo: PhotosPickerItem?
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let wide = sizeClass == .regular && geometry.size.width > 580
        VStack(spacing: 0) {
          if wide {
            if #available(iOS 27.1, *) {
              ArrangementView {
                mainPanel
              } secondary: {
                rightPanel
              }
              .arrangementViewStyle(.split.axes(.horizontal))
              .background { HingeSpine().frame(width: 22).padding(.vertical, 55) }
            } else {
              HStack(spacing: 8) { mainPanel; rightPanel }
            }
          } else {
            ReplicaCover()
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .animation(reduceMotion ? nil : .smooth, value: wide)
      }
      .background(DexTheme.shell.ignoresSafeArea())
      .sheet(isPresented: $settings) { SettingsView(model: model) }
      .sheet(isPresented: $journal) { JournalView(model: model) }
      .fullScreenCover(isPresented: $camera) {
        CameraCapture { image in
          camera = false
          if let image { model.scan(image) }
        }.ignoresSafeArea()
      }
      .alert("Scan needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
        Button("OK", role: .cancel) { model.error = nil }
      } message: { Text(model.error ?? "") }
      .task(id: photo) {
        guard let photo else { return }
        do {
          guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw DexError.message("Couldn’t open this photo. Please select another image.") }
          model.scan(image)
        } catch { model.error = error.localizedDescription }
        self.photo = nil
      }
      .sensoryFeedback(.success, trigger: model.history.count)
    }
    .tint(.white)
    .preferredColorScheme(.dark)
  }

  private var mainPanel: some View {
    HardwareFit {
      LeftHardwarePanel(model: model, photo: $photo, camera: { Task { await openCamera() } }, journal: { journal = true })
    }
  }

  private var rightPanel: some View {
    HardwareFit {
      RightHardwarePanel(model: model, settings: { settings = true }, journal: { journal = true })
    }
  }

  private func openCamera() async {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      model.error = "A camera isn’t available here. Use Choose Photo to scan an image from your library."
      return
    }
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    if granted { camera = true } else { model.error = "Camera access is off. Allow it in system Settings, or choose a photo from your library." }
  }
}

private struct JournalView: View {
  var model: DexModel
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        if model.history.isEmpty {
          ContentUnavailableView("Your adventure starts here", systemImage: "book.closed.fill", description: Text("Scan a Pokémon to save your first discovery."))
        }
        ForEach(model.history) { entry in
          Button {
            model.select(entry)
            dismiss()
          } label: {
            HStack {
              Text(String(format: "#%03d", entry.number)).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
              Text(entry.name).foregroundStyle(.primary)
              Spacer()
              Text(entry.type).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
          }
        }
      }
      .navigationTitle("Field journal")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } } }
    }.tint(.red)
  }
}
