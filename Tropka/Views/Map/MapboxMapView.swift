import SwiftUI
import MapboxMaps
import CoreLocation

/// UIKit wrapper for Mapbox Maps SDK that displays annotations for places.
struct MapboxMapView: UIViewRepresentable {
    typealias UIViewType = MapboxMaps.MapView

    let places: [Place]
    var onPinTapped: (Place) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let options = MapInitOptions(styleURI: .standard)
        let mv = MapboxMaps.MapView(frame: .zero, mapInitOptions: options)
        mv.location.options.puckType = .puck2D()

        context.coordinator.setup(with: mv, onPinTapped: onPinTapped)
        context.coordinator.updateAnnotations(with: places)
        return mv
    }

    func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {
        context.coordinator.onPinTapped = onPinTapped
        context.coordinator.updateAnnotations(with: places)
    }

    class Coordinator: NSObject, CLLocationManagerDelegate {
        var annotationManager: PointAnnotationManager?
        weak var mapView: MapboxMaps.MapView?
        var onPinTapped: ((Place) -> Void)?

        private let locationManager = CLLocationManager()

        override init() {
            super.init()
            locationManager.delegate = self
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleZoomIn),
                                                   name: .zoomIn,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleZoomOut),
                                                   name: .zoomOut,
                                                   object: nil)
        }

        func setup(with mapView: MapboxMaps.MapView, onPinTapped: @escaping (Place) -> Void) {
            self.mapView = mapView
            self.annotationManager = mapView.annotations.makePointAnnotationManager()
            self.onPinTapped = onPinTapped
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()

            // Follow the user puck continuously (like Mapbox tracking mode example)
            let followState = mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 200, left: 0, bottom: 0, right: 0),
                    zoom: 15,
                    bearing: .constant(0),
                    pitch: 0
                )
            )
            mapView.viewport.transition(to: followState)
        }

        func updateAnnotations(with places: [Place]) {
            guard let manager = annotationManager else { return }
            manager.annotations = places.enumerated().map { i, place in
                var ann = PointAnnotation(coordinate: place.coordinates)
                ann.image = .init(image: pinImage(for: place.category), name: "pin-\(place.category.rawValue)")
                ann.iconSize = 0.9
                ann.customData = ["placeIndex": .number(Double(i))]
                ann.tapHandler = { [weak self] _ in
                    self?.onPinTapped?(place)
                    return true
                }
                return ann
            }
        }

        private func pinImage(for category: PlaceCategory) -> UIImage {
            let size = CGSize(width: 28, height: 28)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                let path = UIBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
                category.color.setFill()
                path.fill()
                let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                if let icon = UIImage(systemName: category.icon, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let iconRect = CGRect(x: (size.width - icon.size.width) / 2,
                                          y: (size.height - icon.size.height) / 2,
                                          width: icon.size.width,
                                          height: icon.size.height)
                    icon.draw(in: iconRect)
                }
            }
        }

        // MARK: - Zoom Handling

        @objc private func handleZoomIn() {
            changeZoom(by: 1)
        }

        @objc private func handleZoomOut() {
            changeZoom(by: -1)
        }

        private func changeZoom(by delta: CGFloat) {
            guard let mapView else { return }
            let current = mapView.mapboxMap.cameraState.zoom
            let options = CameraOptions(zoom: current + Double(delta))
            mapView.mapboxMap.setCamera(to: options)
        }

        // MARK: - Location

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            // Camera tracking is handled by viewport — nothing to do here
        }
    }
}
