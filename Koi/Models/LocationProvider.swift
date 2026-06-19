import CoreLocation
import Combine

/// Minimal while-in-use location. Asks permission on demand, takes a single fix, and
/// reverse-geocodes it to a province name so the fuel feed can follow the user. Nothing
/// is stored or sent anywhere — the coordinate lives only in memory while the app is open.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var provinceName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest   // precise — we want the closest station
    }

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }

    /// Ask for permission (if undecided) or refresh the fix (if already granted).
    func requestOrRefresh() {
        switch status {
        case .notDetermined:                          manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default:                                      break
        }
    }

    private func resolve(lat: Double, lon: Double) {
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)) { [weak self] placemarks, _ in
            let name = placemarks?.first?.subAdministrativeArea ?? placemarks?.first?.administrativeArea
            Task { @MainActor in self?.provinceName = name }
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            self?.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self?.manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        let lat = c.latitude, lon = c.longitude
        DispatchQueue.main.async { [weak self] in self?.resolve(lat: lat, lon: lon) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
