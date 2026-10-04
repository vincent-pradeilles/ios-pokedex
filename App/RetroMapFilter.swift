import CoreGraphics

/// A small, one-shot palette conversion rather than a continuously running effect.
enum RetroMapFilter {
  static func render(_ source: CGImage, pixelSize: Int, attributionHeight: Int) -> CGImage? {
    let width = max(1, source.width / pixelSize)
    let height = max(1, source.height / pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let lowResolution: CGImage? = pixels.withUnsafeMutableBytes { bytes in
      guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
      context.interpolationQuality = .low
      context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
      let buffer = bytes.bindMemory(to: UInt8.self)
      for y in 0..<height {
        for x in 0..<width {
          let index = (y * width + x) * 4
          let r = Double(buffer[index]) / 255
          let g = Double(buffer[index + 1]) / 255
          let b = Double(buffer[index + 2]) / 255
          let brightness = r * 0.299 + g * 0.587 + b * 0.114
          let checker = Double((x + y) % 2) * 0.018
          let color: (UInt8, UInt8, UInt8)
          if b > r + 0.035 && b > g - 0.015 {
            // Sea blue with occasional tiled water highlights.
            if y % 8 == 0 && (x + y / 8 * 3) % 12 < 3 {
              color = (123, 188, 223)
            } else {
              color = brightness > 0.70 ? (102, 179, 219) : (64, 133, 189)
            }
          } else if g > r + 0.025 && g > b + 0.025 {
            color = brightness + checker > 0.72 ? (150, 196, 102) : (79, 145, 89)
          } else if brightness < 0.43 {
            color = (56, 87, 77)
          } else if r > b + 0.12 && r > g + 0.04 {
            color = (212, 163, 97)
          } else if brightness + checker > 0.94 {
            color = (250, 240, 191)
          } else if brightness + checker > 0.83 {
            color = (194, 214, 145)
          } else if brightness + checker > 0.64 {
            color = (156, 179, 133)
          } else {
            color = (102, 130, 102)
          }
          buffer[index] = color.0
          buffer[index + 1] = color.1
          buffer[index + 2] = color.2
          buffer[index + 3] = 255
        }
      }
      return context.makeImage()
    }
    guard let lowResolution,
          let output = CGContext(data: nil, width: source.width, height: source.height,
                                 bitsPerComponent: 8, bytesPerRow: source.width * 4,
                                 space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
    output.interpolationQuality = .none
    output.draw(lowResolution, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
    // Preserve the original bottom band, including MapKit's logo and attribution.
    let bandHeight = min(attributionHeight, source.height)
    if let attribution = source.cropping(to: CGRect(x: 0, y: source.height - bandHeight,
                                                   width: source.width, height: bandHeight)) {
      output.draw(attribution, in: CGRect(x: 0, y: 0, width: source.width, height: bandHeight))
    }
    return output.makeImage()
  }
}
