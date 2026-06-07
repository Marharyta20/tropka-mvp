import SwiftUI
import UIKit
import MapboxMaps
import CoreLocation
import Turf

struct MapRepresentable: UIViewRepresentable {

    // Входные данные
    let stops: [Stop]
    let routeCoords: [CLLocationCoordinate2D]
    var selectedStopIndex: Int = 0
    
    // MARK: - Coordinator
    class Coordinator {
        var parent: MapRepresentable
        var pointManager: PointAnnotationManager?
        var polylineManager: PolylineAnnotationManager?
        var cancelables = Set<AnyCancelable>()
        var lastSelectedIndex: Int = -1   // tracks changes
        weak var mapView: MapboxMaps.MapView?

        init(_ parent: MapRepresentable) {
            self.parent = parent
        }
        
        // MARK: - Custom numbered pin image
        func numberedPinImage(number: Int, isFirst: Bool, isLast: Bool,
                              isSelected: Bool = false) -> UIImage {
            let baseSize: CGFloat = isSelected ? 44 : 36
            let circleSize: CGFloat = isSelected ? 38 : 30
            let tailH: CGFloat = isSelected ? 52 : 44
            let size = CGSize(width: baseSize, height: tailH)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                let cx = (baseSize - circleSize) / 2
                let circleRect = CGRect(x: cx, y: cx / 2, width: circleSize, height: circleSize)

                let fillColor: UIColor = isFirst ? .systemGreen
                                       : isLast  ? .systemRed
                                                 : .systemBlue

                // Outer glow ring for selected
                if isSelected {
                    ctx.cgContext.setShadow(offset: .zero, blur: 8,
                                           color: fillColor.withAlphaComponent(0.6).cgColor)
                    fillColor.withAlphaComponent(0.25).setFill()
                    ctx.cgContext.fillEllipse(in: circleRect.insetBy(dx: -5, dy: -5))
                    ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                }

                // Shadow
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2),
                                        blur: 4,
                                        color: UIColor.black.withAlphaComponent(0.35).cgColor)
                fillColor.setFill()
                ctx.cgContext.fillEllipse(in: circleRect)

                // White border
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(isSelected ? 3 : 2)
                ctx.cgContext.strokeEllipse(in: circleRect.insetBy(dx: 1, dy: 1))

                // Triangle tail
                let tailPath = UIBezierPath()
                let midX = baseSize / 2
                let circleBottom = circleRect.maxY
                tailPath.move(to: CGPoint(x: midX - 6, y: circleBottom - 2))
                tailPath.addLine(to: CGPoint(x: midX + 6, y: circleBottom - 2))
                tailPath.addLine(to: CGPoint(x: midX, y: tailH - 1))
                tailPath.close()
                fillColor.setFill()
                tailPath.fill()

                // Number
                let text = "\(number)" as NSString
                let fontSize: CGFloat = isSelected ? 17 : 14
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: circleRect.midX - textSize.width / 2,
                    y: circleRect.midY - textSize.height / 2,
                    width: textSize.width, height: textSize.height)
                text.draw(in: textRect, withAttributes: attrs)
            }
        }

        // MARK: - Fly camera to selected stop
        func flyToSelected(on mapView: MapboxMaps.MapView) {
            let idx = parent.selectedStopIndex
            guard parent.stops.indices.contains(idx) else { return }
            let coord = parent.stops[idx].location
            // Keep current zoom — only pan to the selected stop
            mapView.mapboxMap.setCamera(to: CameraOptions(center: coord))
        }

        // MARK: - Draw all map annotations
        func drawAnnotations(on mapView: MapboxMaps.MapView) {
            guard mapView.mapboxMap.isStyleLoaded else { return }
            self.mapView = mapView

            if pointManager == nil {
                pointManager = mapView.annotations.makePointAnnotationManager()
            }
            if polylineManager == nil {
                polylineManager = mapView.annotations.makePolylineAnnotationManager()
            }

            guard let pointManager = pointManager,
                  let polylineManager = polylineManager else { return }

            // --- PINS with custom numbered images ---
            let totalStops = parent.stops.count
            let selectedIdx = parent.selectedStopIndex
            let points: [PointAnnotation] = parent.stops.enumerated().map { index, stop in
                let isFirst    = index == 0
                let isLast     = index == totalStops - 1
                let isSelected = index == selectedIdx
                let pinImage   = numberedPinImage(number: index + 1,
                                                  isFirst: isFirst,
                                                  isLast: isLast,
                                                  isSelected: isSelected)
                let imageID = "pin-\(index + 1)-\(isSelected ? "sel" : isFirst ? "start" : isLast ? "end" : "mid")"
                try? mapView.mapboxMap.addImage(pinImage, id: imageID)

                var annotation = PointAnnotation(coordinate: stop.location)
                annotation.iconImage = imageID
                annotation.iconAnchor = .bottom
                annotation.iconSize = 1.0
                // Show stop name label below pin
                annotation.textField = stop.name
                annotation.textAnchor = .top
                annotation.textOffset = [0, 0.5]
                annotation.textSize = 11
                annotation.textColor = StyleColor(.black)
                annotation.textHaloColor = StyleColor(.white)
                annotation.textHaloWidth = 2
                return annotation
            }
            pointManager.annotations = points

            // --- ROUTE LINE ---
            let lineCoords = !parent.routeCoords.isEmpty
                ? parent.routeCoords
                : parent.stops.map { $0.location }

            if lineCoords.count > 1 {
                var polyline = PolylineAnnotation(lineCoordinates: lineCoords)
                polyline.lineColor = StyleColor(UIColor.systemBlue)
                polyline.lineWidth = 5.0
                polyline.lineOpacity = 0.9
                polylineManager.annotations = [polyline]
            } else {
                polylineManager.annotations = []
            }

            // --- CAMERA: pad bottom for the stops sheet ---
            if !lineCoords.isEmpty {
                let camera = CameraOptions(bearing: 0, pitch: 0)
                if let fit = try? mapView.mapboxMap.camera(
                    for: lineCoords,
                    camera: camera,
                    coordinatesPadding: UIEdgeInsets(top: 60, left: 40, bottom: 260, right: 40),
                    maxZoom: nil,
                    offset: nil
                ) {
                    mapView.mapboxMap.setCamera(to: fit)
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

        // Blue location puck
        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearing = .heading

        // Draw annotations once style is ready
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak mapView, weak coordinator = context.coordinator] _ in
            guard let mapView, let coordinator else { return }
            coordinator.drawAnnotations(on: mapView)
        }.store(in: &context.coordinator.cancelables)

        // Add +/- zoom buttons
        addZoomButtons(to: mapView)

        return mapView
    }

    private func addZoomButtons(to mapView: MapboxMaps.MapView) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.layer.cornerRadius = 8
        stack.clipsToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        let zoomIn  = makeZoomButton(title: "+", tag: 1, mapView: mapView)
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        let zoomOut = makeZoomButton(title: "−", tag: -1, mapView: mapView)

        stack.addArrangedSubview(zoomIn)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(zoomOut)

        mapView.addSubview(stack)
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            zoomIn.widthAnchor.constraint(equalToConstant: 44),
            zoomIn.heightAnchor.constraint(equalToConstant: 44),
            zoomOut.widthAnchor.constraint(equalToConstant: 44),
            zoomOut.heightAnchor.constraint(equalToConstant: 44),
            stack.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 60),
        ])
    }

    private func makeZoomButton(title: String, tag: Int,
                                mapView: MapboxMaps.MapView) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        btn.backgroundColor = .systemBackground
        btn.tintColor = .label
        btn.tag = tag
        // store weak ref to mapView via closure
        btn.addAction(UIAction { [weak mapView] _ in
            guard let mapView else { return }
            let current = mapView.mapboxMap.cameraState.zoom
            let target  = current + Double(tag)   // +1 or -1
            let clamped = min(max(target, 1), 22)
            mapView.mapboxMap.setCamera(to: CameraOptions(zoom: clamped))
        }, for: .touchUpInside)
        return btn
    }

    // MARK: - Update UIView
    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.drawAnnotations(on: mapView)

        // Fly to selected stop when index changes
        let coordinator = context.coordinator
        if coordinator.lastSelectedIndex != selectedStopIndex {
            coordinator.lastSelectedIndex = selectedStopIndex
            coordinator.flyToSelected(on: mapView)
        }
    }
}

