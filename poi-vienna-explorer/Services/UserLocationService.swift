import Combine
import CoreLocation
import Foundation

@MainActor
final class UserLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var errorMessage: String?

    private let locationManager: CLLocationManager

    override init() {
        let locationManager = CLLocationManager()
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse
    }

    var statusMessage: String? {
        switch authorizationStatus {
        case .notDetermined:
            nil
        case .denied:
            "Location access is off. Enable it in Settings to see your location and distances."
        case .restricted:
            "Location access is restricted on this device."
        case .authorizedAlways, .authorizedWhenInUse:
            if let errorMessage {
                "Location unavailable: \(errorMessage)"
            } else if location == nil {
                "Finding your location…"
            } else {
                nil
            }
        @unknown default:
            "Location access is unavailable."
        }
    }

    func requestLocationWhenInUseIfNeeded() {
        authorizationStatus = locationManager.authorizationStatus
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are turned off."
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        case .denied, .restricted:
            location = nil
        @unknown default:
            errorMessage = "Location access is unavailable."
        }
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard CLLocationManager.locationServicesEnabled() else {
                errorMessage = "Location Services are turned off."
                return
            }
            startUpdatingLocation()
        case .notDetermined:
            break
        case .denied, .restricted:
            location = nil
            locationManager.stopUpdatingLocation()
        @unknown default:
            errorMessage = "Location access is unavailable."
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestValidLocation = locations.reversed().first(where: {
            $0.horizontalAccuracy >= 0
                && POIDistanceCalculator.isValid($0.coordinate)
        }) else {
            return
        }
        location = latestValidLocation
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    private func startUpdatingLocation() {
        errorMessage = nil
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
    }
}
