import Foundation

struct DexEntry: Codable, Identifiable {
  var id = UUID()
  var name: String
  var number: Int
  var type: String
  var summary: String
  var imageName: String?
  var isSample = false
  // Optional for compatibility with discoveries saved before mode selection.
  var removalMode: BackgroundRemovalMode?
  var location: ScanLocation?

  static let empty = DexEntry(name: "Ready to capture", number: 0, type: "—", summary: "No Pokémon captured yet.\n\nTake a picture or choose a photo to begin your next discovery.")

}
