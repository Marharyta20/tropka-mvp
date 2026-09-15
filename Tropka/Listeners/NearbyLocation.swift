import CoreLocation
import Combine
import Foundation

/// Where the user is, for screens that want it but do not own a map.
///
/// The map has its own `CLLocationManager` because it needs a live puck. Explore
/// needs one coordinate, once, to answer "what is near me" — so this asks for a
/// single fix and stops. It never requests permission of its own: the map already
/// asks, at the moment the ask makes sense. Somebody who opens Explore first and
/// has never seen the map gets no prompt and no nearby card, which is the right
/// trade — a location prompt on the home screen before the app has shown a map is
/// how permission dialogs get refused for good.
@MainActor
final class NearbyLocation: NSObject, ObservableObject {
    static let shared = NearbyLocation()

    /// nil until a fix arrives, and nil forever if permission was never granted.
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var isRequesting = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorised: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// Asks for a fix if we are allowed one and are not already waiting.
    ///
    /// Safe to call from `.task` on every appearance: a coordinate we already
    /// have is good enough for "which places are near me", and re-requesting on
    /// every visit would spend battery to move a card by one entry.
    func refreshIfNeeded() {
        guard isAuthorised, coordinate == nil, !isRequesting else { return }
        isRequesting = true
        manager.requestLocation()
    }
}

extension NearbyLocation: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            isRequesting = false
            coordinate = last.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // No fix: the screen falls back to a city-wide pick. Nothing to report —
        // the user did not ask for a location, they asked for a home screen.
        Task { @MainActor in isRequesting = false }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in refreshIfNeeded() }
    }
}
