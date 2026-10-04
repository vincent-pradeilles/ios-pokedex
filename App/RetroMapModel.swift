import SwiftUI
import MapKit

@MainActor @Observable
final class RetroMapModel {
  var image: UIImage?
  var pin = CGPoint.zero
  var accuracyRadius: CGFloat = 0
  var loading = false
  var failed = false
  private var requestID = UUID()

  func load(location: ScanLocation, size: CGSize, zoom: Int) async {
    let id = UUID()
    requestID = id
    loading = true
    failed = false
    image = nil
    let options = MKMapSnapshotter.Options()
    options.size = size
    options.scale = 2
    options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
    let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
    configuration.pointOfInterestFilter = .excludingAll
    configuration.showsTraffic = false
    options.preferredConfiguration = configuration
    let meters = max(1000, location.horizontalAccuracy * 4) * pow(2, Double(zoom))
    options.region = MKCoordinateRegion(center: location.coordinate,
                                        latitudinalMeters: meters,
                                        longitudinalMeters: meters)
    let snapshotter = MKMapSnapshotter(options: options)
    do {
      let snapshot = try await withTaskCancellationHandler {
        try await snapshotter.start()
      } onCancel: {
        Task { @MainActor in snapshotter.cancel() }
      }
      try Task.checkCancellation()
      guard requestID == id else { return }
      guard let source = snapshot.image.cgImage else { throw SnapshotError.missingImage }
      let rendered = await Task.detached(priority: .userInitiated) {
        RetroMapFilter.render(source, pixelSize: 6, attributionHeight: 80)
      }.value
      try Task.checkCancellation()
      guard requestID == id else { return }
      guard let rendered else { throw SnapshotError.missingImage }
      pin = snapshot.point(for: location.coordinate)
      let center = MKMapPoint(location.coordinate)
      let offset = location.horizontalAccuracy * MKMapPointsPerMeterAtLatitude(location.latitude)
      let edge = snapshot.point(for: MKMapPoint(x: center.x + offset, y: center.y).coordinate)
      accuracyRadius = abs(edge.x - pin.x)
      image = UIImage(cgImage: rendered, scale: snapshot.image.scale, orientation: .up)
      loading = false
    } catch {
      guard requestID == id else { return }
      loading = false
      failed = !Task.isCancelled
    }
  }
}

private enum SnapshotError: Error { case missingImage }
