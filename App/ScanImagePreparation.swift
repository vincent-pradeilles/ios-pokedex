import UIKit

/// Keep resizing and JPEG encoding off the UI thread so the captured still can render first.
actor ScanImagePreparation {
  func prepare(_ image: UIImage, removal: BackgroundRemovalMode, recognition: RecognitionMode) throws -> PreparedScan {
    try Task.checkCancellation()
    CaptureTiming.mark("scan preflight started")
    let photoroomKey = removal == .photoroom ? KeychainStore.read() : ""
    guard removal != .photoroom || !photoroomKey.isEmpty else {
      throw DexError.message("Add your Photoroom API key in Settings before capturing a Pokémon.")
    }
    let geminiKey = recognition == .gemini ? KeychainStore.read(for: .gemini) : ""
    switch recognition {
    case .gemini:
      guard !geminiKey.isEmpty else { throw DexError.message("Add your Gemini API key in Settings before capturing a Pokémon.") }
    case .onDevice:
      if let reason = OnDeviceIdentificationService.unavailabilityReason { throw DexError.message(reason) }
    }
    CaptureTiming.mark("scan preflight finished")
    let scale = min(1, 1600 / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    guard let data = normalized.jpegData(compressionQuality: 0.9) else {
      throw DexError.message("Couldn’t prepare this picture.")
    }
    try Task.checkCancellation()
    return PreparedScan(data: data, photoroomKey: photoroomKey, geminiKey: geminiKey)
  }
}

struct PreparedScan {
  var data: Data
  var photoroomKey: String
  var geminiKey: String
}
