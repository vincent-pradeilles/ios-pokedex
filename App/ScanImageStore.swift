import UIKit
import ImageIO

/// Original transparent cutouts live in Documents, independently of the view lifecycle.
enum ScanImageStore {
  static var directory: URL {
    URL.documentsDirectory.appendingPathComponent("Scans", isDirectory: true)
  }

  static func save(_ data: Data, named name: String) throws {
    guard let image = UIImage(data: data), let png = image.pngData() else {
      throw DexError.message("Couldn’t save this Pokémon’s image. Please try scanning again.")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // PNG retains the removed background's transparency; atomic writes avoid partial files.
    try png.write(to: directory.appendingPathComponent(name), options: .atomic)
  }

  static func image(named name: String) -> UIImage? {
    UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
  }

  static func thumbnail(named name: String) async -> UIImage? {
    await Task.detached(priority: .utility) {
      let url = directory.appendingPathComponent(name)
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true,
              kCGImageSourceThumbnailMaxPixelSize: 320,
              kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else { return nil }
      return UIImage(cgImage: image)
    }.value
  }
}
