import Foundation

struct PokemonIdentification: Decodable {
  var recognized: Bool
  var name: String
  var number: Int
  var type: String
  var summary: String
}
