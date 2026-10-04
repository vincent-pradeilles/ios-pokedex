import CoreGraphics

/// Reconstructs the snapshot's color regions as original pixel-art terrain.
/// Decorative foliage and roof shading are illustrative, not additional map data.
enum RetroMapFilter {
  static func render(_ source: CGImage, pixelSize: Int, attributionHeight: Int) -> CGImage? {
    guard pixelSize > 0 else { return nil }
    let width = max(1, source.width / pixelSize)
    let height = max(1, source.height / pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let artwork: CGImage? = pixels.withUnsafeMutableBytes { bytes in
      guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
      context.interpolationQuality = .low
      context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
      let buffer = bytes.bindMemory(to: UInt8.self)
      let terrain = PixelTerrain(width: width, height: height, source: buffer)
      terrain.draw(into: buffer)
      return context.makeImage()
    }
    guard let artwork,
          let output = CGContext(data: nil, width: source.width, height: source.height,
                                 bitsPerComponent: 8, bytesPerRow: source.width * 4,
                                 space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
    output.interpolationQuality = .none
    output.draw(artwork, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
    // Preserve MapKit's original attribution rather than filtering its lettering.
    let bandHeight = max(0, min(attributionHeight, source.height))
    if bandHeight > 0, let attribution = source.cropping(to: CGRect(x: 0, y: source.height - bandHeight,
                                                                  width: source.width, height: bandHeight)) {
      output.draw(attribution, in: CGRect(x: 0, y: 0, width: source.width, height: bandHeight))
    }
    return output.makeImage()
  }
}

private struct PixelTerrain {
  private enum Tile: Int { case grass, forest, water, path, roof, lettering }
  private typealias RGB = (UInt8, UInt8, UInt8)
  var width: Int
  var height: Int
  private var tiles: [Tile]

  init(width: Int, height: Int, source: UnsafeMutableBufferPointer<UInt8>) {
    self.width = width
    self.height = height
    tiles = (0..<(width * height)).map { index in
      let r = Double(source[index * 4]) / 255
      let g = Double(source[index * 4 + 1]) / 255
      let b = Double(source[index * 4 + 2]) / 255
      let light = (r + g + b) / 3
      let chroma = max(r, g, b) - min(r, g, b)
      if light < 0.70 { return .lettering }
      if b > r + 0.07 && b > g - 0.025 { return .water }
      if g > r + 0.035 && g > b + 0.06 { return .forest }
      if light > 0.965 && chroma < 0.04 { return .path }
      if light < 0.89 && chroma < 0.045 { return .path }
      if light < 0.945 && chroma < 0.045 { return .roof }
      if r > b + 0.045 && light < 0.935 { return .roof }
      return .grass
    }
    // Remove map lettering before texturing; dark labels aren't terrain boundaries.
    let original = tiles
    for y in 0..<height {
      for x in 0..<width where original[y * width + x] == .lettering {
        var votes = [Int](repeating: 0, count: 5)
        for dy in -5...5 {
          for dx in -5...5 {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
            let tile = original[ny * width + nx]
            if tile != .lettering { votes[tile.rawValue] += 1 }
          }
        }
        let best = votes.indices.max { votes[$0] < votes[$1] } ?? 0
        tiles[y * width + x] = Tile(rawValue: best) ?? .grass
      }
    }
    // A small majority pass removes antialiased flecks without moving broad shorelines.
    let resolved = tiles
    for y in 1..<max(1, height - 1) {
      for x in 1..<max(1, width - 1) {
        var votes = [Int](repeating: 0, count: 5)
        for dy in -1...1 {
          for dx in -1...1 { votes[resolved[(y + dy) * width + x + dx].rawValue] += 1 }
        }
        if let best = votes.indices.max(by: { votes[$0] < votes[$1] }), votes[best] >= 6 {
          tiles[y * width + x] = Tile(rawValue: best) ?? .grass
        }
      }
    }
  }

  private func tile(_ x: Int, _ y: Int) -> Tile {
    tiles[max(0, min(height - 1, y)) * width + max(0, min(width - 1, x))]
  }

  private func noise(_ x: Int, _ y: Int) -> Int {
    ((x &* 374761393) ^ (y &* 668265263)) & 255
  }

  func draw(into buffer: UnsafeMutableBufferPointer<UInt8>) {
    func put(_ x: Int, _ y: Int, _ color: RGB) {
      guard x >= 0, x < width, y >= 0, y < height else { return }
      let index = (y * width + x) * 4
      buffer[index] = color.0; buffer[index + 1] = color.1
      buffer[index + 2] = color.2; buffer[index + 3] = 255
    }
    for y in 0..<height {
      for x in 0..<width {
        let current = tile(x, y)
        let grain = noise(x, y)
        let color: RGB
        switch current {
        case .water:
          let bank = [tile(x - 1, y), tile(x + 1, y), tile(x, y - 1), tile(x, y + 1)].contains { $0 != .water }
          let shallow = tile(x - 3, y) != .water || tile(x + 3, y) != .water || tile(x, y - 3) != .water
          let ripple = (x + (y % 7) * 2) % 13
          if bank { color = (51, 76, 139) }
          else if shallow { color = (126, 168, 223) }
          else if ripple < 2 && y % 5 < 3 { color = (129, 166, 230) }
          else if ripple == 3 { color = (75, 112, 188) }
          else { color = (93, 138, 211) }
        case .path:
          let edge = tile(x - 1, y) == .grass || tile(x + 1, y) == .grass || tile(x, y - 1) == .forest
          color = edge ? (218, 192, 116) : grain < 24 ? (231, 211, 140) : grain > 245 ? (255, 243, 177) : (246, 227, 156)
        case .roof:
          let bottom = tile(x, y + 1) != .roof
          let wall = tile(x, y + 3) != .roof || tile(x, y + 4) != .roof
          let top = tile(x, y - 1) != .roof
          let side = tile(x - 1, y) != .roof || tile(x + 1, y) != .roof
          if bottom || side { color = (102, 70, 52) }
          else if top { color = (255, 204, 99) }
          else if wall { color = x % 9 < 3 ? (107, 156, 177) : (217, 211, 171) }
          else if y % 9 == 0 { color = (143, 76, 40) }
          else { color = x % 3 == 0 ? (241, 168, 69) : (201, 117, 45) }
        case .grass, .forest, .lettering:
          let shore = tile(x, y + 1) == .water || tile(x - 1, y) == .water
          if shore { color = (55, 107, 88) }
          else if grain < 9 { color = (60, 149, 107) }
          else if grain > 244 { color = (134, 204, 144) }
          else { color = current == .forest ? (95, 177, 116) : (106, 189, 145) }
        }
        put(x, y, color)
      }
    }
    // Place hand-drawn foliage only inside the map's green regions. Keep paths clear.
    for cy in stride(from: 12, to: height - 12, by: 22) {
      for cx in stride(from: 10 + ((cy / 22) % 2) * 8, to: width - 10, by: 19) {
        let forestPixels = (-8...8).reduce(0) { count, dx in
          count + (-10...10).filter { dy in tile(cx + dx, cy + dy) == .forest }.count
        }
        guard tile(cx, cy) == .forest, forestPixels > 270 else { continue }
        func foliage(_ x: Int, _ y: Int, _ color: RGB) {
          if tile(x, y) == .forest { put(x, y, color) }
        }
        func ellipse(_ ox: Int, _ oy: Int, _ rx: Int, _ ry: Int, _ color: RGB) {
          for dy in -ry...ry {
            for dx in -rx...rx where dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry {
              foliage(cx + ox + dx, cy + oy + dy, color)
            }
          }
        }
        ellipse(1, 9, 8, 3, (53, 125, 81))
        for y in 6...10 { for x in -1...1 { foliage(cx + x, cy + y, (126, 94, 54)) } }
        for (oy, rx, ry) in [(3, 8, 5), (-2, 6, 5), (-7, 4, 4)] {
          ellipse(0, oy, rx, ry, (37, 103, 65))
          ellipse(0, oy - 1, rx - 1, ry - 1, (62, 150, 71))
          ellipse(-1, oy - 2, max(1, rx - 2), max(1, ry - 2), (112, 193, 79))
          for dx in stride(from: -rx + 2, through: rx - 2, by: 3) {
            foliage(cx + dx, cy + oy + 1, (47, 126, 65))
            foliage(cx + dx, cy + oy - 2, (158, 215, 102))
          }
        }
      }
    }
  }
}
