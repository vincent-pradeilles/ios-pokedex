import Foundation

enum RecognitionMode: String, Codable, CaseIterable, Identifiable {
  case onDevice
  case gemini

  var id: String { rawValue }

  var title: String {
    switch self {
    case .onDevice: "On device"
    case .gemini: "Gemini"
    }
  }

  var explanation: String {
    switch self {
    case .onDevice: "Recognize Pokémon privately on your iPhone using Apple Intelligence. Requires iOS 27 or later and an available on-device model. No Gemini key is needed. Photoroom still receives photos if selected for background removal."
    case .gemini: "Send the background-removed image to Google Gemini for recognition. Requires internet access and a Gemini API key; API usage may incur charges."
    }
  }
}
