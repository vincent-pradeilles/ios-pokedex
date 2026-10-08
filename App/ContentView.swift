import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
  @State private var model = DexModel()
  @State private var settings = false
  @State private var journal = false
  @State private var camera = CameraCapture()
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
      .alert("Capture needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
        Button("OK", role: .cancel) { model.error = nil }
      } message: { Text(model.error ?? "") }
      .task(id: photo) {
        guard let photo else { return }
        camera.stop()
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
        if phase == .background { camera.stop() }
      }
      .onChange(of: settings) { _, value in if value { camera.stop() } }
      .onChange(of: journal) { _, value in if value { camera.stop() } }
      .onDisappear { camera.stop() }
      .sensoryFeedback(.success, trigger: model.history.count)
    }
    .tint(.white)
    .preferredColorScheme(.dark)
  }

  private var mainPanel: some View {
    HardwareFit {
      LeftHardwarePanel(model: model, photo: $photo, capture: camera, camera: { Task { await openCamera() } }, journal: { journal = true })
    }
  }

  private var rightPanel: some View {
    HardwareFit {
      RightHardwarePanel(model: model, settings: { settings = true }, journal: { journal = true })
    }
  }

  private func openCamera() async {
    guard !model.busy else { return }
    do {
      if camera.isActive {
        if let image = try await camera.capture() { model.scan(image) }
      } else {
        model.narrator.stop()
        try await camera.start()
      }
    } catch { model.error = error.localizedDescription }
  }
}
