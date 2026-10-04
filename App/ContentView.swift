import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
  @State private var model = DexModel()
  @State private var settings = false
  @State private var journal = false
  @State private var camera = false
  @State private var photo: PhotosPickerItem?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let wide = sizeClass == .regular && geometry.size.width > 580
        Group {
          if wide {
            if #available(iOS 27.1, *) {
              DuoHardwareLayout {
                mainPanel
              } right: {
                rightPanel
              }
            } else {
              HStack(spacing: 0) { mainPanel; rightPanel }
            }
          } else {
            ReplicaCover()
          }
        }
      }
      .ignoresSafeArea()
      .statusBarHidden()
      .persistentSystemOverlays(.hidden)
      .modifier(ImmersiveHardwarePresentation())
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
      .alert("Narration unavailable", isPresented: Binding(get: { model.narrator.error != nil }, set: { if !$0 { model.narrator.error = nil } })) {
        Button("OK", role: .cancel) { model.narrator.error = nil }
      } message: { Text(model.narrator.error ?? "") }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active { model.narrator.stop() }
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
    if granted { model.narrator.stop(); camera = true } else { model.error = "Camera access is off. Allow it in system Settings, or choose a photo from your library." }
  }
}
