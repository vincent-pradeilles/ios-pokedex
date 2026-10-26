import SwiftUI

struct SettingsView: View {
  @Bindable var model: DexModel
  @State private var apiKey = ""
  @State private var saved = false
  @State private var error: String?
  @State private var confirmsDeletion = false
  @State private var deletionError: String?
  @State private var dataDeleted = false
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
        } header: { Text("Capture processing") } footer: {
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
            Text("Your key is stored securely in this iPhone’s Keychain. Clear the field and save to remove it. Each capture sends your selected photo to Photoroom for background removal and a soft AI shadow. This uses the Image Editing API (Plus plan) and its credits.")
          }
        }
        Section("On-device identification") {
          Label(model.modelStatus, systemImage: "viewfinder")
          Text("After background removal, Apple’s on-device model identifies the Pokémon. Apple Intelligence and iOS 27 or later are required. AI matches and field notes can be inaccurate.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section {
          Toggle("Read new discoveries aloud", isOn: $model.narrator.automaticallyNarrates)
          Toggle("Electronic voice effect", isOn: $model.narrator.electronicEffect)
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
          Text("A US-English system voice with a radio-style filter and subtle electronic doubling inspired by the reference clip. This is an approximation, not the anime’s original voice. Tap the yellow speaker button to replay an entry.")
        }
        Section {
          Button("Delete All Persisted Data", role: .destructive) {
            confirmsDeletion = true
          }
          .disabled(model.busy)
          if dataDeleted {
            Text("Saved data has been deleted. Your saved API keys have been kept.")
              .foregroundStyle(.secondary)
          }
        } header: { Text("Saved data") } footer: {
          Text(model.busy
               ? "Wait for the current capture to finish before deleting saved data."
               : "Permanently deletes discoveries, scan images, and saved locations, and resets all settings on this device. Saved API keys are kept.")
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
      .alert("Delete All Persisted Data?", isPresented: $confirmsDeletion) {
        Button("Cancel", role: .cancel) { }
        Button("Delete All Data", role: .destructive) {
          dataDeleted = false
          do {
            try model.deleteAllPersistedData()
            apiKey = KeychainStore.read()
            saved = false
            dataDeleted = true
          } catch {
            apiKey = KeychainStore.read()
            deletionError = error.localizedDescription
          }
        }
      } message: {
        Text("All discoveries, scan images, and saved locations will be deleted from this device. All settings will reset. Saved API keys will be kept. This cannot be undone.")
      }
      .alert("Couldn’t Delete All Data", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
        Button("OK", role: .cancel) { deletionError = nil }
      } message: { Text(deletionError ?? "") }
      .alert("Couldn’t save key", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        Button("OK", role: .cancel) { error = nil }
      } message: { Text(error ?? "") }
    }.tint(.red)
  }
}
