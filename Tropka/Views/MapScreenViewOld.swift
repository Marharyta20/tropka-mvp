import SwiftUI
import MapboxMaps
import CoreLocation

struct MapScreenViewOld: UIViewRepresentable {
    /// Если вам нужны кастомные пины — используйте stops, иначе можно оставить пустым
    var stops: [CLLocationCoordinate2D] = []

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MapView {
        let options = MapInitOptions(styleURI: .streets)
        let mapView = MapView(frame: .zero, mapInitOptions: options)
        mapView.translatesAutoresizingMaskIntoConstraints = false

        // 1️⃣ show the 2D “puck”
        mapView.location.options.puckType = .puck2D()

        // 2️⃣ recenter on every location update (keep the subscription alive)
        _ = mapView.location.onLocationChange
          .observeNext { [weak mapView] locations in
            guard
              let mapView = mapView,
              let latest = locations.last
            else { return }
            let cam = CameraOptions(center: latest.coordinate, zoom: 14.0)
            mapView.mapboxMap.setCamera(to: cam)
          }

        // 3️⃣ now you request & start CoreLocation – as before
        context.coordinator.locationManager.requestWhenInUseAuthorization()
        context.coordinator.locationManager.startUpdatingLocation()

        // 🔴 ADD: сразу после старта, если уже есть lastLocation – центрируемся раз
        if let loc = context.coordinator.locationManager.location {
            let cam = CameraOptions(center: loc.coordinate, zoom: 14.0)
            mapView.mapboxMap.setCamera(to: cam)
        }

        return mapView
    }



    func updateUIView(_ uiView: MapView, context: Context) {
        // здесь можно, при желании, обновлять аннотации из stops
    }

    // MARK: — Coordinator

    class Coordinator: NSObject, CLLocationManagerDelegate {
        let parent: MapScreenViewOld
        let locationManager = CLLocationManager()

        init(_ parent: MapScreenViewOld) {
            self.parent = parent
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }

        // — CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager,
                             didChangeAuthorization status: CLAuthorizationStatus) {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager,
                             didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                locationUpdate(newLocation: location)
            }
        }

        // MARK: - Location Consumer (Custom Protocol)
        // Define a simple protocol for location updates
        protocol LocationConsumer: AnyObject {
            func locationUpdate(newLocation: CLLocation)
        }

        weak var locationDelegate: LocationConsumer?

        func locationUpdate(newLocation: CLLocation) {
            // Центрируем камеру на каждое новое местоположение
            centerMap(on: newLocation.coordinate)
            locationDelegate?.locationUpdate(newLocation: newLocation)
        }

        private func centerMap(on coord: CLLocationCoordinate2D) {
            guard let mapView = findMapView() else { return }
            let camera = CameraOptions(center: coord, zoom: 14.0)
            mapView.mapboxMap.setCamera(to: camera)
        }

        private func findMapView() -> MapView? {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .compactMap { $0.rootViewController?.view }
                .flatMap { $0.subviews }
                .compactMap { $0 as? MapView }
                .first
        }
    }
}
