import SwiftUI
import MapKit

struct ScanLocationView: View {
  var entry: DexEntry
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if let location = entry.location {
          Map(initialPosition: .region(MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: max(1000, location.horizontalAccuracy * 4),
            longitudinalMeters: max(1000, location.horizontalAccuracy * 4)
          ))) {
            Marker(entry.name, coordinate: location.coordinate)
            MapCircle(center: location.coordinate, radius: location.horizontalAccuracy)
              .foregroundStyle(.blue.opacity(0.15))
          }
          .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
              Text(entry.name).font(.headline)
              Text("Latitude: \(location.latitude.formatted(.number.precision(.fractionLength(5))))")
              Text("Longitude: \(location.longitude.formatted(.number.precision(.fractionLength(5))))")
              Text("Accuracy: about \(location.horizontalAccuracy.formatted(.number.precision(.fractionLength(0)))) m")
                .foregroundStyle(.secondary)
              Text(location.capturedAt, format: .dateTime.month().day().year().hour().minute())
                .foregroundStyle(.secondary)
              Text("Device location when captured, including captures from your photo library.")
                .font(.footnote).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
          }
        } else {
          ContentUnavailableView {
            Label("No location saved", systemImage: "mappin.and.ellipse")
          } description: {
            Text("This capture has no recorded coordinates. For future captures, allow location access in Settings and capture Pokémon where a location signal is available.")
          }
        }
      }
      .navigationTitle("Capture Location")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
      }
    }
  }
}
