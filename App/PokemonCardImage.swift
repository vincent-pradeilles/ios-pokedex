import SwiftUI

struct PokemonCardImage: View {
  var number: Int
  var entry: DexEntry?
  @State private var thumbnail: UIImage?
  @State private var loading = false

  var body: some View {
    GeometryReader { geometry in
      Group {
        if entry == nil {
          Image("pokemon-\(number)")
            .renderingMode(.template)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .foregroundStyle(.black)
            .frame(width: 96, height: 96)
        } else if let thumbnail {
          Image(uiImage: thumbnail)
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.9)
        } else if loading {
          ProgressView().tint(.black)
        } else {
          Text("Image unavailable")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .aspectRatio(1, contentMode: .fit)
    .background(Color(red: 0.82, green: 0.88, blue: 0.77), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityHidden(true)
    .task(id: entry?.imageName) {
      thumbnail = nil
      guard let name = entry?.imageName else { loading = false; return }
      loading = true
      let savedImage = await ScanImageStore.thumbnail(named: name)
      guard !Task.isCancelled else { return }
      thumbnail = savedImage
      loading = false
    }
  }
}
