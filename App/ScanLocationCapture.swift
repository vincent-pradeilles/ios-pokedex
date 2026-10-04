import CoreLocation

/// A single, bounded location request owned by one scan, never background tracking.
@MainActor
final class ScanLocationCapture: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var continuation: CheckedContinuation<ScanLocation?, Never>?
  private var timeout: Task<Void, Never>?
  private var startedAt = Date()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func capture() async -> ScanLocation? {
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        guard !Task.isCancelled else { continuation.resume(returning: nil); return }
        self.continuation = continuation
        startedAt = Date()
        timeout = Task { [weak self] in
          do { try await Task.sleep(for: .seconds(20)) }
          catch { return }
          self?.finish(nil)
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: finish(nil)
        }
      }
    } onCancel: {
      Task { @MainActor in self.finish(nil) }
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard continuation != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
    case .denied, .restricted: finish(nil)
    default: break
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last(where: {
      $0.horizontalAccuracy >= 0 && $0.timestamp >= startedAt.addingTimeInterval(-5)
        && CLLocationCoordinate2DIsValid($0.coordinate)
    }) else { finish(nil); return }
    finish(ScanLocation(latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        horizontalAccuracy: location.horizontalAccuracy,
                        capturedAt: location.timestamp))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(nil)
  }

  private func finish(_ location: ScanLocation?) {
    manager.stopUpdatingLocation()
    timeout?.cancel()
    timeout = nil
    let pending = continuation
    continuation = nil
    pending?.resume(returning: location)
  }
}
