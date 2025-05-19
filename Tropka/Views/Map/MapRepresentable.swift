import SwiftUI
import MapboxMaps
import FirebaseFirestore   // нужен для GeoPoint ➜ CLLocationCoordinate2D

/// Показывает карту с пинами и линией маршрута.
/// Передаём stops через Binding, чтобы SwiftUI реагировал на изменения.
struct MapRepresentable: UIViewRepresentable {

    @Binding var stops: [Stop]

    /// Ссылки наружу, чтобы RouteMapView могла двигать камеру и т. д.
    @Binding var mapViewRef: MapView?
    @Binding var pinManagerRef: PointAnnotationManager?
    @Binding var lineManagerRef: PolylineAnnotationManager?

    // MARK: - makeUIView
    func makeUIView(context: Context) -> MapView {
        let options = MapInitOptions(styleURI: .streets)
        let mapView = MapView(frame: .zero, mapInitOptions: options)

        // store reference outward
        DispatchQueue.main.async {
            mapViewRef = mapView
        }

        // 1️⃣ менеджеры аннотаций
        pinManagerRef  = mapView.annotations.makePointAnnotationManager()
        lineManagerRef = mapView.annotations.makePolylineAnnotationManager()

        // начальная заливка пинов (если stops уже есть)
        updatePinsAndLine()

        return mapView
    }

    // MARK: - updateUIView
    func updateUIView(_ uiView: MapView, context: Context) {
        // вызывается, когда @Binding stops изменился
        updatePinsAndLine()
    }

    // MARK: - helpers
    private func updatePinsAndLine() {
        guard let pinMgr  = pinManagerRef,
              let lineMgr = lineManagerRef else { return }

        // очистим прежнее
        pinMgr.annotations.removeAll()
        lineMgr.annotations.removeAll()

        // сортируем по orderIndex
        let sorted = stops.sorted { $0.orderIndex < $1.orderIndex }

        // преобразуем в PointAnnotation
        var points: [PointAnnotation] = []
        var coords: [CLLocationCoordinate2D] = []

        for s in sorted {
            let coord = CLLocationCoordinate2D(latitude:  s.coordinates.latitude,
                                               longitude: s.coordinates.longitude)
            coords.append(coord)

            var point = PointAnnotation(coordinate: coord)
            point.image = .default  // либо кастомный Asset
            point.textField      = "\(s.orderIndex)"
            point.textColor      = .white
            point.textHaloColor  = .black
            point.textHaloWidth  = 1.5
            point.textAnchor     = .bottom
            points.append(point)
        }

        pinMgr.annotations = points

        // polyline
        if coords.count >= 2 {
            let pline = PolylineAnnotation(lineCoordinates: coords)
            pline.lineWidth  = 3
            pline.lineColor  = .init(UIColor.systemBlue)
            lineMgr.annotations = [pline]
        }
    }
}
