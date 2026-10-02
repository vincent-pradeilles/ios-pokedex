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

  static let sample = DexEntry(name: "Pikachu", number: 25, type: "Electric", summary: "It stores electricity in the pouches on its cheeks. When it’s excited, tiny sparks crackle from its cheeks.", imageName: "pikachu", isSample: true)
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
