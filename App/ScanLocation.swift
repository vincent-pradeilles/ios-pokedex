import CoreLocation

struct ScanLocation: Codable {
  var latitude: Double
  var longitude: Double
  var horizontalAccuracy: Double
  var capturedAt: Date

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
