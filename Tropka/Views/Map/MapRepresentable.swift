import SwiftUI
import UIKit
import MapboxMaps
import CoreLocation
import FirebaseFirestore
import Turf

// Расширение для GeoPoint
extension GeoPoint {
    var clCoord: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}

struct MapRepresentable: UIViewRepresentable {
    
    // Входные данные
    let stops: [Stop]
    let routeCoords: [CLLocationCoordinate2D]
    
    // MARK: - Coordinator
    class Coordinator {
        var parent: MapRepresentable
        var pointManager: PointAnnotationManager?
        var polylineManager: PolylineAnnotationManager?
        var cancelables = Set<AnyCancelable>()
        
        init(_ parent: MapRepresentable) {
            self.parent = parent
        }
        
        // Главная функция рисования
        func drawAnnotations(on mapView: MapboxMaps.MapView) {
            // 1. Проверяем, готова ли карта
            guard mapView.mapboxMap.isStyleLoaded else { return }
            
            // 2. Инициализируем менеджеры, если их еще нет
            if pointManager == nil {
                pointManager = mapView.annotations.makePointAnnotationManager()
            }
            if polylineManager == nil {
                polylineManager = mapView.annotations.makePolylineAnnotationManager()
            }
            
            guard let pointManager = pointManager,
                  let polylineManager = polylineManager else { return }
            
            // --- РИСУЕМ ПИНЫ ---
            let points: [PointAnnotation] = parent.stops.enumerated().map { index, stop in
                var annotation = PointAnnotation(coordinate: stop.coordinates.clCoord)
                annotation.iconImage = "default-pin" // Ссылка на картинку
                annotation.iconColor = StyleColor(.red)
                annotation.textField = "\(index + 1)"
                annotation.textColor = StyleColor(.black)
                annotation.textOffset = [0, -2.0]
                annotation.textSize = 14
                return annotation
            }
            pointManager.annotations = points
            
            // --- РИСУЕМ ЛИНИЮ ---
            let lineCoordinates = !parent.routeCoords.isEmpty ? parent.routeCoords : parent.stops.map { $0.coordinates.clCoord }
            
            if lineCoordinates.count > 1 {
                var polyline = PolylineAnnotation(lineCoordinates: lineCoordinates)
                polyline.lineColor = StyleColor(.systemBlue)
                polyline.lineWidth = 5.0
                polyline.lineOpacity = 0.8
                polylineManager.annotations = [polyline]
            } else {
                polylineManager.annotations = []
            }
            
            // --- КАМЕРА ---
            if !lineCoordinates.isEmpty {
                let cameraOptions = CameraOptions(bearing: 0, pitch: 0)
                
                // Используем try? чтобы не упало, если расчет не удался
                if let camera = try? mapView.mapboxMap.camera(
                    for: lineCoordinates,
                    camera: cameraOptions,
                    coordinatesPadding: .init(top: 50, left: 50, bottom: 50, right: 50),
                    maxZoom: nil,
                    offset: nil
                ) {
                    mapView.mapboxMap.setCamera(to: camera)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Make UIView
    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let myMapInitOptions = MapInitOptions(styleURI: .outdoors)
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: myMapInitOptions)
        
        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.compassView.isHidden = false
        
        // Подписываемся на событие "Стиль загружен"
        if let image = UIImage(systemName: "mappin.circle.fill")?.withRenderingMode(.alwaysTemplate) {
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak coordinator = context.coordinator] _ in
                guard let coordinator = coordinator else { return }
                
                // 1. Добавляем картинку
                try? mapView.mapboxMap.addImage(image, id: "default-pin")
                
                // 2. ВАЖНО: Вызываем перерисовку, так как теперь стиль точно готов
                coordinator.drawAnnotations(on: mapView)
                
            }.store(in: &context.coordinator.cancelables)
        }
        
        return mapView
    }

    // MARK: - Update UIView
    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        // Обновляем данные в координаторе
        context.coordinator.parent = self
        
        // Пытаемся нарисовать.
        // Если стиль еще не готов, drawAnnotations внутри сделает return,
        // но сработает observeNext из makeUIView чуть позже.
        context.coordinator.drawAnnotations(on: mapView)
    }
}
