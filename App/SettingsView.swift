import SwiftUI

struct SettingsView: View {
  @Bindable var model: DexModel
  @State private var apiKey = ""
  @State private var saved = false
  @State private var error: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Background removal", selection: $model.removalMode) {
            ForEach(BackgroundRemovalMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }.pickerStyle(.segmented)
            .disabled(model.busy)
        } header: { Text("Scan processing") } footer: {
          Text(model.removalMode.explanation)
        }
        if model.removalMode == .photoroom {
          Section {
            SecureField("Photoroom API key", text: $apiKey)
              .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button(saved ? "Key saved" : "Save key", systemImage: "checkmark") {
              do {
                try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                saved = true
              } catch { self.error = error.localizedDescription }
            }
            Link("Photoroom API dashboard", destination: URL(string: "https://app.photoroom.com/api-dashboard")!)
          } header: { Text("Photoroom & AI Shadows") } footer: {
            Text("Your key is stored securely in this iPhone’s Keychain. Clear the field and save to remove it. Each scan sends your selected photo to Photoroom for background removal and a soft AI shadow. This uses the Image Editing API (Plus plan) and its credits.")
          }
        }
        Section("On-device identification") {
          Label(model.modelStatus, systemImage: "viewfinder")
          Text("After background removal, Apple’s on-device model identifies the Pokémon. Apple Intelligence and iOS 27 or later are required. AI matches and field notes can be inaccurate.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section {
          Toggle("Read new discoveries aloud", isOn: $model.narrator.automaticallyNarrates)
          Picker("US-English voice", selection: $model.narrator.voiceIdentifier) {
            Text("Automatic").tag("")
            ForEach(model.narrator.availableVoices, id: \.identifier) { voice in
              Text(voice.name).tag(voice.identifier)
            }
          }
          Button(model.narrator.isSpeaking ? "Stop narration" : "Preview voice",
                 systemImage: model.narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill") {
            if model.narrator.isSpeaking { model.narrator.stop() }
            else { model.narrator.preview() }
          }
        } header: { Text("Pokédex voice") } footer: {
          Text("A low-pitched US-English system voice inspired by the original electronic delivery. This is an approximation, not the anime’s original voice. Tap the yellow speaker button to replay an entry.")
        }
        Section("About") {
          LabeledContent("Pocket Dex", value: "1.0")
          Text("An independent fan project. Pokémon and Pokémon character names are trademarks of Nintendo, Creatures, and GAME FREAK.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } } }
      .onAppear { apiKey = KeychainStore.read() }
      .onChange(of: apiKey) { saved = false }
      .alert("Couldn’t save key", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        Button("OK", role: .cancel) { error = nil }
      } message: { Text(error ?? "") }
    }.tint(.red)
  }
}
