import Foundation
import CoreLocation

// MARK: - Church location manager
//
// Thin CoreLocation wrapper for the Church Finder. Free (native), no keys.
// Requests when-in-use permission and publishes the user's location so the
// finder can search for churches nearby.

final class ChurchLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var isRequesting = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Requests permission if needed, then a one-shot location fix.
    func request() {
        isRequesting = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            isRequesting = false
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            manager.requestLocation()
        } else if isDenied {
            isRequesting = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last { location = loc }
        isRequesting = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
    }
}
