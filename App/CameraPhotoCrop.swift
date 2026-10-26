import UIKit

/// Retains the centered aspect-fill crop shown by the live camera viewport.
enum CameraPhotoCrop {
  static func crop(_ image: UIImage, to viewport: CGSize) -> UIImage {
    let source = image.size
    let fill = max(viewport.width / source.width, viewport.height / source.height)
    let visibleSize = CGSize(width: viewport.width / fill, height: viewport.height / fill)
    // Match the scan pipeline's resolution limit without changing the crop.
    let scale = min(1, 1600 / max(visibleSize.width, visibleSize.height))
    let output = CGSize(width: visibleSize.width * scale, height: visibleSize.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: output, format: format).image { _ in
      // UIImage drawing applies EXIF orientation before cropping, including
      // portrait and upside-down captures whose CGImage pixels are rotated.
      image.draw(in: CGRect(
        x: (visibleSize.width - source.width) * scale / 2,
        y: (visibleSize.height - source.height) * scale / 2,
        width: source.width * scale,
        height: source.height * scale
      ))
    }
  }
}
