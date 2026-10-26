import Foundation

enum BackgroundRemovalMode: String, Codable, CaseIterable, Identifiable {
  case onDevice
  case photoroom

  var id: String { rawValue }
  var title: String {
    switch self {
    case .onDevice: "On device"
    case .photoroom: "Photoroom"
    }
  }
  var explanation: String {
    switch self {
    case .onDevice: "Remove backgrounds privately on your iPhone with a subtle display shadow. Background removal needs no Photoroom key or credits. Recognition uses the model selected below."
    case .photoroom: "Send photos to Photoroom for background removal and controllable AI shadows. Requires an API key and Image Editing API credits."
    }
  }
}
