import SwiftUI
import MapboxMaps

/// UIKit wrapper for Mapbox Maps SDK that displays annotations for places.
struct MapboxMapView: UIViewRepresentable {
    let places: [Place]
    var onPinTapped: (Place) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MapView {
        let options = MapInitOptions(styleURI: .streets)
        let mv = MapView(frame: .zero, mapInitOptions: options)
        mv.location.options.puckType = .puck2D()

        context.coordinator.annotationManager = mv.annotations.makePointAnnotationManager()
        context.coordinator.mapView = mv
        context.coordinator.onPinTapped = onPinTapped
        context.coordinator.updateAnnotations(with: places)
        return mv
    }

    func updateUIView(_ uiView: MapView, context: Context) {
        context.coordinator.onPinTapped = onPinTapped
        context.coordinator.updateAnnotations(with: places)
    }

    class Coordinator {
        var annotationManager: PointAnnotationManager?
        weak var mapView: MapView?
        var onPinTapped: ((Place) -> Void)?

        func updateAnnotations(with places: [Place]) {
            guard let manager = annotationManager else { return }
            manager.annotations = places.enumerated().map { i, place in
                var ann = PointAnnotation(coordinate: place.coordinates)
                ann.image = .init(image: pinImage(for: place.category), name: "pin-\(place.category.rawValue)")
                ann.iconSize = 1.2
                ann.customData = ["placeIndex": .number(Double(i))]
                ann.tapHandler = { [weak self] _ in
                    self?.onPinTapped?(place)
                    return true
                }
                return ann
            }
        }

        private func pinImage(for category: PlaceCategory) -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                let path = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
                category.color.setFill()
                path.fill()
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                if let icon = UIImage(systemName: category.icon, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let iconRect = CGRect(x: (size.width - icon.size.width) / 2,
                                          y: (size.height - icon.size.height) / 2,
                                          width: icon.size.width,
                                          height: icon.size.height)
                    icon.draw(in: iconRect)
                }
            }
        }
    }
}
