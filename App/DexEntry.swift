import Foundation
import FoundationModels

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

  static let empty = DexEntry(name: "Ready to scan", number: 0, type: "—", summary: "No Pokémon scanned yet.\n\nTake a picture or choose a photo to begin your next discovery.")

}

@available(iOS 27.0, *)
@Generable
struct PokemonIdentification {
  @Guide(description: "True only if the image clearly depicts a recognizable Pokémon. Otherwise false; do not guess.")
  var recognized: Bool
  @Guide(description: "The English Pokémon species name, or Unknown.")
  var name: String
  @Guide(description: "National Pokédex number, or 0 if unknown.")
  var number: Int
  @Guide(description: "Pokémon elemental types, separated by a slash.")
  var type: String
  @Guide(description: "Two short factual sentences about this species. If unknown, explain how to take a clearer photo.")
  var summary: String
}
