import Foundation
import Vision
import CoreImage

actor LocalBackgroundRemoval {
  private let context = CIContext()

  func process(_ data: Data) throws -> Data {
    try Task.checkCancellation()
    let handler = VNImageRequestHandler(data: data, orientation: .up)
    let request = VNGenerateForegroundInstanceMaskRequest()
    do {
      try handler.perform([request])
      try Task.checkCancellation()
      guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
        throw DexError.message("No clear subject found. Try one Pokémon against a simple background with good lighting.")
      }
      // Preserve the source canvas so the reveal remains registered to the photo.
      let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
        from: handler, croppedToInstancesExtent: false)
      try Task.checkCancellation()
      let image = CIImage(cvPixelBuffer: buffer)
      guard let png = context.pngRepresentation(of: image, format: .RGBA8,
        colorSpace: CGColorSpaceCreateDeviceRGB()) else {
        throw DexError.message("Couldn’t create the transparent image. Try another photo.")
      }
      return png
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as DexError {
      throw error
    } catch {
      // Never fall back to a network upload without the selected mode changing.
      throw DexError.message("On-device background removal couldn’t process this photo. Try a clearer picture, or choose Photoroom in Settings.")
    }
  }
}
