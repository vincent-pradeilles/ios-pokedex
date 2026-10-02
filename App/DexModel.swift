import SwiftUI
import FoundationModels

@MainActor @Observable
final class DexModel {
  var entry = DexEntry.empty
  var originalPhoto: UIImage?
  var cutout: UIImage?
  var subjectBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
  var history: [DexEntry] = []
  var phase = "Ready to explore"
  var busy = false
  var error: String?
  var task: Task<Void, Never>?
  var removalMode: BackgroundRemovalMode {
    didSet { UserDefaults.standard.set(removalMode.rawValue, forKey: "backgroundRemovalMode") }
  }
  private let service = ScanService()
  private let localRemoval = LocalBackgroundRemoval()

  init() {
    let storedMode = UserDefaults.standard.string(forKey: "backgroundRemovalMode")
    removalMode = storedMode.flatMap(BackgroundRemovalMode.init(rawValue:))
      ?? (KeychainStore.read().isEmpty ? .onDevice : .photoroom)
    if let data = UserDefaults.standard.data(forKey: "entries"),
       let entries = try? JSONDecoder().decode([DexEntry].self, from: data) { history = entries }
  }

  var modelStatus: String {
    guard #available(iOS 27.0, *) else { return "Image identification requires iOS 27 or later." }
    switch SystemLanguageModel.default.availability {
    case .available: return "On-device model ready"
    case .unavailable(.appleIntelligenceNotEnabled): return "Enable Apple Intelligence in system Settings to identify Pokémon."
    case .unavailable(.modelNotReady): return "Apple’s on-device model is downloading. Try again when it is ready."
    case .unavailable: return "On-device identification isn’t available on this device. Try a supported iPhone with Apple Intelligence."
    }
  }

  func scan(_ image: UIImage) {
    guard !busy else { return }
    let mode = removalMode
    let key = mode == .photoroom ? KeychainStore.read() : ""
    guard mode != .photoroom || !key.isEmpty else { error = "Add your Photoroom API key in Settings before scanning."; return }
    guard #available(iOS 27.0, *), SystemLanguageModel.default.availability == .available else { error = modelStatus; return }
    originalPhoto = image
    cutout = nil
    entry = DexEntry(name: "Scanning…", number: 0, type: "Unknown", summary: "Isolating your Pokémon. Identification will begin as soon as its background is removed.")
    entry.removalMode = mode
    busy = true
    phase = "Scanning…"
    task = Task {
      defer { busy = false; task = nil }
      do {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let normalized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = normalized.jpegData(compressionQuality: 0.9) else { throw DexError.message("Couldn’t prepare this picture.") }
        let result: Data
        switch mode {
        case .onDevice:
          result = try await localRemoval.process(data)
        case .photoroom:
          result = try await service.prepareCutout(image: data, key: key)
        }
        try Task.checkCancellation()
        // Publish the cutout before awaiting identification so the reveal and local inference overlap.
        let preparedImage = UIImage(data: result)
        subjectBounds = CutoutFraming.visibleBounds(of: preparedImage)
        cutout = preparedImage
        entry.name = "Identifying…"
        entry.summary = "Background removed. Your iPhone is identifying this Pokémon while it settles into the display."
        phase = "Identifying on your iPhone…"
        let identity = try await service.identify(result)
        try Task.checkCancellation()
        guard identity.recognized, identity.number > 0 else { throw DexError.message("No confident match. Try one Pokémon, well lit and filling the picture.") }
        let newEntry = DexEntry(name: identity.name, number: identity.number, type: identity.type, summary: identity.summary, removalMode: mode)
        let file = newEntry.id.uuidString + ".png"
        try result.write(to: Self.storage.appendingPathComponent(file), options: .atomic)
        var savedEntry = newEntry
        savedEntry.imageName = file
        entry = savedEntry
        cutout = UIImage(data: result)
        history.insert(savedEntry, at: 0)
        UserDefaults.standard.set(try JSONEncoder().encode(history), forKey: "entries")
        phase = "New discovery"
      } catch is CancellationError {
        phase = "Scan cancelled"
        entry.name = "Scan cancelled"
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
        phase = "Ready to try again"
        entry.name = "Unidentified"
        entry.summary = "No identification was saved. Try a clear photo of one Pokémon."
      }
    }
  }

  func cancel() { task?.cancel() }

  func select(_ item: DexEntry) {
    originalPhoto = nil
    entry = item
    cutout = item.imageName.flatMap { UIImage(contentsOfFile: Self.storage.appendingPathComponent($0).path) }
    subjectBounds = CutoutFraming.visibleBounds(of: cutout)
    phase = "Saved discovery"
  }

  static var storage: URL {
    let url = URL.documentsDirectory.appendingPathComponent("Scans", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
