import UIKit

/// Finds the visible subject and its AI shadow, ignoring transparent canvas.
enum CutoutFraming {
  static func visibleBounds(of image: UIImage?) -> CGRect {
    let full = CGRect(x: 0, y: 0, width: 1, height: 1)
    guard let cgImage = image?.cgImage else { return full }
    let ratio = min(1, 512.0 / Double(max(cgImage.width, cgImage.height)))
    let width = max(1, Int(Double(cgImage.width) * ratio))
    let height = max(1, Int(Double(cgImage.height) * ratio))
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    return pixels.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
      else { return full }
      // Bitmap rows retain the CGImage's top-to-bottom order; do not flip.
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      var minX = width, minY = height, maxX = -1, maxY = -1
      for y in 0..<height {
        for x in 0..<width where buffer[(y * width + x) * 4 + 3] > 1 {
          minX = min(minX, x); maxX = max(maxX, x)
          minY = min(minY, y); maxY = max(maxY, y)
        }
      }
      guard maxX >= minX, maxY >= minY else { return full }
      // Include a small sampling allowance around faint shadow/antialiased edges.
      minX = max(0, minX - 2); minY = max(0, minY - 2)
      maxX = min(width - 1, maxX + 2); maxY = min(height - 1, maxY + 2)
      return CGRect(x: CGFloat(minX) / CGFloat(width), y: CGFloat(minY) / CGFloat(height),
        width: CGFloat(maxX - minX + 1) / CGFloat(width), height: CGFloat(maxY - minY + 1) / CGFloat(height))
    }
  }
}
