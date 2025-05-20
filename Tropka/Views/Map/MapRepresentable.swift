import SwiftUI
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

    // MARK: bindings для «наружи»
    @Binding var mapView: MapView?
    @Binding var pinManager: PointAnnotationManager?
    @Binding var lineManager: PolylineAnnotationManager?

    let stops: [Stop]
    let routeCoords: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MapView {
        let opts = MapInitOptions(styleURI: .streets)
        let mv = MapView(frame: .zero, mapInitOptions: opts)

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

    func updateUIView(_ uiView: MapView, context: Context) {
        // если пришёл новый массив остановок → перерисовать
        guard let pins = pinManager,
              let lines = lineManager else { return }
        pins.annotations.removeAll()
        lines.annotations.removeAll()
        addAnnotations(on: uiView, pins: pins, line: lines)
    }

    // MARK: helpers
    private func addAnnotations(on mv: MapView,
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
        
        fitCamera(mv: mv, coords: coords)
        
        // ♦︎ FIT CAMERA to route  –––––––––––––––––––––––––––––––––––––
        func fitCamera(mv: MapView, coords: [CLLocationCoordinate2D]) {
                guard !coords.isEmpty else { return }

                do {
                    let cam = try mv.mapboxMap.camera(
                        for: coords,                                   // Geometry → coords
                        camera: CameraOptions(center: nil, zoom: nil), // базовая (nil = “как есть”)
                        coordinatesPadding: .init(top: 60,
                                                  left: 40,
                                                  bottom: 260,
                                                  right: 40),
                        maxZoom: nil,
                        offset: .zero)
                    mv.mapboxMap.setCamera(to: cam)
                } catch {
                    print("❌ camera-fit error:", error)
                }
            }

    }
}
