import Foundation
import CoreLocation
import Combine

/// Wraps CoreLocation to publish the device's current coordinate and keep it
/// updated as the phone moves, using low-power significant-change monitoring
/// so it also works while the app is backgrounded.
final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    @Published var coordinate: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    var onLocationUpdate: (() -> Void)?

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestOneTimeLocation() {
        manager.requestLocation()
    }

    func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let place = placemarks?.first else { return }
            let name = [place.locality, place.country].compactMap { $0 }.joined(separator: ", ")
            DispatchQueue.main.async {
                self.placeName = name.isEmpty ? nil : name
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
            startMonitoring()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        reverseGeocode(location)
        onLocationUpdate?()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location temporarily unavailable; the last known coordinate (if any) stays in use.
    }
}
