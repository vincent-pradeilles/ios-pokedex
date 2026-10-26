import SwiftUI

@MainActor @Observable
final class DexModel {
  var narrator = DexNarrator()
  var entry = DexEntry.empty
  var originalPhoto: UIImage?
  var cutout: UIImage?
  var subjectBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
  var history: [DexEntry] = []
  var phase = "Ready to explore"
  var busy = false
  var error: String?
  var task: Task<Void, Never>?
  var recognitionMode: RecognitionMode {
    didSet { UserDefaults.standard.set(recognitionMode.rawValue, forKey: "recognitionMode") }
  }
  var removalMode: BackgroundRemovalMode {
    didSet { UserDefaults.standard.set(removalMode.rawValue, forKey: "backgroundRemovalMode") }
  }
  private let service = ScanService()
  private let localRemoval = LocalBackgroundRemoval()
  private let imagePreparation = ScanImagePreparation()

  init() {
    recognitionMode = UserDefaults.standard.string(forKey: "recognitionMode")
      .flatMap(RecognitionMode.init(rawValue:)) ?? .gemini
    let storedMode = UserDefaults.standard.string(forKey: "backgroundRemovalMode")
    removalMode = storedMode.flatMap(BackgroundRemovalMode.init(rawValue:))
      ?? (KeychainStore.read().isEmpty ? .onDevice : .photoroom)
    if let data = UserDefaults.standard.data(forKey: "entries"),
       let entries = try? JSONDecoder().decode([DexEntry].self, from: data) { history = entries }
  }

  var capturedSpecies: Set<Int> {
    Set(history.filter { !$0.isSample && (1...386).contains($0.number) }.map(\.number))
  }

  var latestScans: [Int: DexEntry] {
    history.filter { !$0.isSample }.reduce(into: [:]) { result, entry in
      if result[entry.number] == nil { result[entry.number] = entry }
    }
  }

  func scan(_ image: UIImage) {
    guard !busy else { return }
    let mode = removalMode
    let recognition = recognitionMode
    if narrator.isSpeaking { narrator.stop() }
    originalPhoto = image
    cutout = nil
    entry = DexEntry(name: "Processing…", number: 0, type: "Unknown", summary: "Isolating your Pokémon. Identification will begin as soon as its background is removed.")
    entry.removalMode = mode
    busy = true
    phase = "Removing background…"
    CaptureTiming.mark("still installed")
    task = Task {
      defer { busy = false; task = nil }
      let locationCapture = ScanLocationCapture()
      async let scanLocation = locationCapture.capture()
      do {
        let prepared = try await imagePreparation.prepare(image, removal: mode, recognition: recognition)
        let data = prepared.data
        CaptureTiming.mark("JPEG ready")
        let result: Data
        switch mode {
        case .onDevice:
          result = try await localRemoval.process(data)
        case .photoroom:
          result = try await service.prepareCutout(image: data, key: prepared.photoroomKey)
        }
        try Task.checkCancellation()
        // Publish the cutout before awaiting either recognition provider.
        guard let preparedImage = UIImage(data: result) else {
          throw DexError.message("Couldn’t read the background-removed photo. Please try again.")
        }
        subjectBounds = CutoutFraming.visibleBounds(of: preparedImage)
        cutout = preparedImage
        entry.name = "Identifying…"
        entry.summary = "Background removed. Identifying this Pokémon while it settles into the display."
        phase = recognition == .gemini ? "Identifying with Gemini…" : "Identifying on your iPhone…"
        let identity = try await service.identify(result, mode: recognition, key: prepared.geminiKey)
        try Task.checkCancellation()
        guard identity.recognized, identity.number > 0 else { throw DexError.message("No confident match. Try one Pokémon, well lit and filling the picture.") }
        let newEntry = DexEntry(name: identity.name, number: identity.number, type: identity.type, summary: identity.summary, removalMode: mode)
        let file = newEntry.id.uuidString + ".png"
        try ScanImageStore.save(result, named: file)
        var savedEntry = newEntry
        savedEntry.imageName = file
        savedEntry.location = await scanLocation
        try Task.checkCancellation()
        entry = savedEntry
        let updatedHistory = [savedEntry] + history
        let savedHistory = try JSONEncoder().encode(updatedHistory)
        UserDefaults.standard.set(savedHistory, forKey: "entries")
        history = updatedHistory
        phase = "New discovery"
        if narrator.automaticallyNarrates { narrator.narrate(savedEntry) }
      } catch is CancellationError {
        phase = "Capture cancelled"
        entry.name = "Capture cancelled"
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
        phase = "Ready to try again"
        entry.name = "Unidentified"
        entry.summary = "No identification was saved. Try a clear photo of one Pokémon."
      }
    }
  }

  func cancel() { task?.cancel() }

  func deleteAllPersistedData() throws {
    // An in-flight scan must finish before its files and preferences can be removed.
    guard !busy else { throw DexError.message("Wait for the current capture to finish, then try again.") }
    guard let domain = Bundle.main.bundleIdentifier else {
      throw DexError.message("Couldn’t access the app’s saved settings.")
    }
    try ScanImageStore.deleteAll()
    narrator.stop()
    history = []
    entry = .empty
    originalPhoto = nil
    cutout = nil
    subjectBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    phase = "Ready to explore"
    error = nil
    removalMode = KeychainStore.read().isEmpty ? .onDevice : .photoroom
    recognitionMode = .gemini
    // Clear preferences after assigning properties that persist through didSet.
    UserDefaults.standard.removePersistentDomain(forName: domain)
    narrator = DexNarrator()
    URLCache.shared.removeAllCachedResponses()
  }

  func select(_ item: DexEntry) {
    narrator.stop()
    originalPhoto = nil
    entry = item
    cutout = item.imageName.flatMap { ScanImageStore.image(named: $0) }
    subjectBounds = CutoutFraming.visibleBounds(of: cutout)
    phase = "Saved discovery"
  }

}
