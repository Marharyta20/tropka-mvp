import SwiftUI
import UIKit
import MapboxMaps
import CoreLocation
import FirebaseFirestore
import Turf

extension GeoPoint {
    var clCoord: CLLocationCoordinate2D {
        .init(latitude: latitude,
              longitude: longitude)
    }
}

struct MapRepresentable: UIViewRepresentable {
    typealias UIViewType = MapboxMaps.MapView

    // MARK: bindings для «наружи»
    @Binding var mapView: MapboxMaps.MapView?
    @Binding var pinManager: PointAnnotationManager?
    @Binding var lineManager: PolylineAnnotationManager?

    let stops: [Stop]
    let routeCoords: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let opts = MapInitOptions(styleURI: .streets)
        let mv = MapboxMaps.MapView(frame: CGRect.zero, mapInitOptions: opts)

        // сохраняем наружу
        DispatchQueue.main.async { mapView = mv }

        // менеджеры
        let pins = mv.annotations.makePointAnnotationManager()
        let lines = mv.annotations.makePolylineAnnotationManager()
        DispatchQueue.main.async {
            pinManager  = pins
            lineManager = lines
        }

        // рисуем точки + полилинию
        addAnnotations(on: mv, pins: pins, line: lines)

        return mv
    }

    func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {
        // если пришёл новый массив остановок → перерисовать
        guard let pins = pinManager,
              let lines = lineManager else { return }
        pins.annotations.removeAll()
        lines.annotations.removeAll()
        addAnnotations(on: uiView, pins: pins, line: lines)
    }

    // MARK: helpers
    private func addAnnotations(on mv: MapboxMaps.MapView,
                                pins: PointAnnotationManager,
                                line: PolylineAnnotationManager) {

        // ♦︎ точки
        let pointAnnots: [PointAnnotation] = stops.enumerated().map { idx, stop in
                    var pa = PointAnnotation(coordinate: stop.coordinates.clCoord)
            pa.image = .init(image: UIImage(named: "pin")!, name: "pin")
            pa.textField       = "\(idx + 1)"
                        pa.textSize        = 12
                        pa.textAnchor      = .bottom
                        pa.textOffset      = [0,-0.5]
            return pa
        }
        pins.annotations = pointAnnots

        // ♦︎ ROUTE POLYLINE
        let coords = !routeCoords.isEmpty ? routeCoords
                                           : stops.map { $0.coordinates.clCoord }
        if coords.count > 1 {
            var poly = PolylineAnnotation(lineCoordinates: coords)
            poly.lineWidth  = 3
            poly.lineColor  = StyleColor(.systemBlue)
            line.annotations = [poly]
        }
        
        fitCamera(on: mv, coords: coords)
    }
    
    // Fits camera to provided coordinates using Mapbox v10 API
    private func fitCamera(on mv: MapboxMaps.MapView, coords: [CLLocationCoordinate2D]) {
        guard !coords.isEmpty else { return }

        // Compute bounding box
        var minLat = coords.first!.latitude
        var maxLat = coords.first!.latitude
        var minLon = coords.first!.longitude
        var maxLon = coords.first!.longitude

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        // Center of the bounds
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)

        // Approximate zoom level based on longitude span and view width.
        // This is a heuristic; Mapbox's exact fitting API isn't used here to avoid `mapboxMap` dependency.
        let lonDelta = max(maxLon - minLon, 0.00001)
        let viewWidth = max(Double(mv.bounds.width), 1.0)
        // 256 is the tile size; clamp zoom between 0...20
        var zoom = log2(360.0 * viewWidth / 256.0 / lonDelta)
        if zoom.isNaN || !zoom.isFinite { zoom = 10 }
        zoom = min(max(zoom, 0), 20)

        // Apply some padding by reducing zoom a bit if we have multiple points
        if coords.count > 1 { zoom -= 0.5 }

        // Set camera instantly (no animation) to avoid race with initial layout
        mv.camera.ease(to: CameraOptions(center: center, zoom: zoom), duration: 0)
    }
}

