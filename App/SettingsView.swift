import SwiftUI

struct SettingsView: View {
  var model: DexModel
  @State private var apiKey = ""
  @State private var saved = false
  @State private var error: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("Photoroom API key", text: $apiKey)
            .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
          Button(saved ? "Key saved" : "Save key", systemImage: saved ? "checkmark" : "checkmark") {
            do {
              try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
              saved = true
            } catch { self.error = error.localizedDescription }
          }
          Link("Photoroom API dashboard", destination: URL(string: "https://app.photoroom.com/api-dashboard")!)
        } header: { Text("Background removal") } footer: {
          Text("Your key is stored securely in this iPhone’s Keychain. Clear the field and save to remove it. Each scan sends your selected photo to Photoroom and uses your API account’s credits.")
        }
        Section("On-device identification") {
          Label(model.modelStatus, systemImage: "viewfinder")
          Text("After background removal, Apple’s on-device model identifies the Pokémon. Apple Intelligence and iOS 27 or later are required. AI matches and field notes can be inaccurate.")
            .font(.footnote).foregroundStyle(.secondary)
        }
        Section("About") {
          LabeledContent("Pocket Dex", value: "1.0")
          Text("An independent fan project. Pokémon and Pokémon character names are trademarks of Nintendo, Creatures, and GAME FREAK. Sample artwork provided through PokeAPI.")
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
