// Run from the project root:
// swiftc App/RetroMapFilter.swift Tests/RetroMapFilterChecks.swift -o /tmp/RetroMapFilterChecks && /tmp/RetroMapFilterChecks
import Foundation
import CoreGraphics

@main
struct RetroMapFilterChecks {
  static func main() {
    let width = 120
    let height = 120
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let i = (y * width + x) * 4
        let color: (UInt8, UInt8, UInt8) = y < 60 ? (170, 210, 240) : (120, 190, 100)
        pixels[i] = color.0; pixels[i+1] = color.1; pixels[i+2] = color.2
        if y >= 108 { pixels[i] = UInt8(x); pixels[i+1] = UInt8(y); pixels[i+2] = 40 }
      }
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let source = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let result = RetroMapFilter.render(source, pixelSize: 6, attributionHeight: 12)!
    let output = Array(result.dataProvider!.data! as Data)
    assert(result.width == source.width && result.height == source.height)
    assert(Array(output[(108*width*4)...]) == Array(pixels[(108*width*4)...]), "Attribution band must remain pixel-identical")
    assert(output[4*width*30] != pixels[4*width*30], "Map must be transformed")
    assert(output[4*width*30+2] > output[4*width*30], "Water must remain blue")
    assert(output[4*width*90+1] > output[4*width*90], "Land must remain green")
    for x in 1..<6 { assert(output[4*(width*30+x)] == output[4*width*30], "Pixels should form hard blocks") }
    let repeated = RetroMapFilter.render(source, pixelSize: 6, attributionHeight: 12)!
    assert(output == Array(repeated.dataProvider!.data! as Data), "Terrain must be deterministic")
    assert(RetroMapFilter.render(source, pixelSize: 0, attributionHeight: 12) == nil)
    // A park split by a white road must retain that road after tree decoration.
    var park = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width where !(56..<64).contains(x) {
        let index = (y * width + x) * 4
        park[index] = 180; park[index + 1] = 225; park[index + 2] = 140
      }
    }
    let parkProvider = CGDataProvider(data: Data(park) as CFData)!
    let parkSource = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: parkProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let parkImage = RetroMapFilter.render(parkSource, pixelSize: 1, attributionHeight: 0)!
    let decorated = Array(parkImage.dataProvider!.data! as Data)
    for y in 0..<height {
      let index = (y * width + 60) * 4
      assert(decorated[index] > 210 && decorated[index + 2] < 190, "Trees must not cover paths")
    }
    let forestColors = Set(stride(from: 0, to: decorated.count, by: 4).map {
      UInt32(decorated[$0]) << 16 | UInt32(decorated[$0 + 1]) << 8 | UInt32(decorated[$0 + 2])
    })
    assert(forestColors.contains(0x256741), "Park should include shaded tree sprites")
    print("PASS: image dimensions, palette mapping, pixel blocks, unchanged attribution band, deterministic terrain, and trees respecting paths")
  }
}
