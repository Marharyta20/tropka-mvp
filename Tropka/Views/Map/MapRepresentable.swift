import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// The map behind a single route: numbered stops and the walking line between them.
struct MapRepresentable: UIViewRepresentable {

    let stops: [Stop]
    let routeCoords: [CLLocationCoordinate2D]
    var selectedStopIndex: Int = 0
    /// Bumped by the recenter button to fit the whole route back on screen.
    var recenterTrigger: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Make

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .standard))

        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.compassView.isHidden = false

        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearing = .heading
        // Tilting is what makes the Standard style draw buildings in 3D — useful on
        // a walking route, where the buildings are the landmarks.
        mapView.gestures.options.pitchEnabled = true

        mapView.mapboxMap.onStyleLoaded.observeNext { [weak mapView, weak coordinator = context.coordinator] _ in
            guard let mapView, let coordinator else { return }
            coordinator.applyLightPreset(to: mapView)
            coordinator.draw(on: mapView)
            coordinator.fitRoute(on: mapView, animated: false)
        }.store(in: &context.coordinator.cancelables)

        return mapView
    }

    // MARK: - Update

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.draw(on: mapView)

        // Refit only when asked. The old version refitted on every state change, so
        // the camera jumped back the moment anything on screen updated.
        if coordinator.lastRecenterTrigger != recenterTrigger {
            coordinator.lastRecenterTrigger = recenterTrigger
            coordinator.fitRoute(on: mapView, animated: true)
            return
        }

        if coordinator.lastSelectedIndex != selectedStopIndex {
            coordinator.lastSelectedIndex = selectedStopIndex
            coordinator.flyToSelected(on: mapView)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        var parent: MapRepresentable
        var cancelables = Set<AnyCancelable>()
        var lastSelectedIndex = -1
        var lastRecenterTrigger = 0

        private var pointManager: PointAnnotationManager?
        private var polylineManager: PolylineAnnotationManager?
        private var lastDrawnSignature = ""

        init(_ parent: MapRepresentable) {
            self.parent = parent
        }

        func applyLightPreset(to mapView: MapboxMaps.MapView) {
            let hour = Calendar.current.component(.hour, from: Date())
            let preset: String
            switch hour {
            case 5..<8:   preset = "dawn"
            case 8..<17:  preset = "day"
            case 17..<21: preset = "dusk"
            default:      preset = "night"
            }
            try? mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap", config: "lightPreset", value: preset
            )
        }

        // MARK: Drawing

        func draw(on mapView: MapboxMaps.MapView) {
            guard mapView.mapboxMap.isStyleLoaded else { return }

            if pointManager == nil {
                pointManager = mapView.annotations.makePointAnnotationManager()
            }
            if polylineManager == nil {
                polylineManager = mapView.annotations.makePolylineAnnotationManager()
            }
            guard let pointManager, let polylineManager else { return }

            // Redrawing every pin bitmap on each SwiftUI update is wasteful; the
            // signature covers everything that changes what is on screen.
            let signature = "\(parent.stops.map(\.id).joined())|\(parent.selectedStopIndex)|\(parent.routeCoords.count)"
            guard signature != lastDrawnSignature else { return }
            lastDrawnSignature = signature

            let total = parent.stops.count
            pointManager.annotations = parent.stops.enumerated().map { index, stop in
                let image = numberedPinImage(number: index + 1,
                                             name: stop.name,
                                             isFirst: index == 0,
                                             isLast: index == total - 1,
                                             isSelected: index == parent.selectedStopIndex)
                let id = "stop-\(index)-\(index == parent.selectedStopIndex ? "sel" : "idle")"
                try? mapView.mapboxMap.addImage(image, id: id)

                var annotation = PointAnnotation(coordinate: stop.location)
                annotation.iconImage = id
                annotation.iconAnchor = .bottom
                annotation.iconSize = 1.0
                return annotation
            }

            let line = parent.routeCoords.isEmpty ? parent.stops.map(\.location) : parent.routeCoords
            guard line.count > 1 else {
                polylineManager.annotations = []
                return
            }

            var casing = PolylineAnnotation(lineCoordinates: line)
            casing.lineColor = StyleColor(UIColor.white)
            casing.lineWidth = 9
            casing.lineOpacity = 0.9

            var route = PolylineAnnotation(lineCoordinates: line)
            route.lineColor = StyleColor(UIColor.systemBlue)
            route.lineWidth = 5.5
            route.lineOpacity = 0.95

            polylineManager.annotations = [casing, route]
        }

        // MARK: Camera

        func fitRoute(on mapView: MapboxMaps.MapView, animated: Bool) {
            let line = parent.routeCoords.isEmpty ? parent.stops.map(\.location) : parent.routeCoords
            guard !line.isEmpty,
                  let camera = try? mapView.mapboxMap.camera(
                      for: line,
                      camera: CameraOptions(bearing: 0, pitch: 0),
                      coordinatesPadding: UIEdgeInsets(top: 80, left: 40, bottom: 220, right: 40),
                      maxZoom: nil,
                      offset: nil
                  )
            else { return }

            if animated {
                mapView.camera.fly(to: camera, duration: 0.6)
            } else {
                mapView.mapboxMap.setCamera(to: camera)
            }
        }

        /// Ease rather than jump: on a walking route the relationship between two
        /// stops is the information, and a cut throws it away.
        func flyToSelected(on mapView: MapboxMaps.MapView) {
            guard parent.stops.indices.contains(parent.selectedStopIndex) else { return }
            let target = parent.stops[parent.selectedStopIndex].location
            let zoom = max(mapView.mapboxMap.cameraState.zoom, 15)
            mapView.camera.fly(to: CameraOptions(center: target, zoom: zoom), duration: 0.5)
        }

        // MARK: Pin image

        /// A numbered circle with a pointer tail anchored to the exact coordinate,
        /// plus a name tag above it. The name is baked into the bitmap so it cannot
        /// collide with the basemap's own labels.
        func numberedPinImage(number: Int, name: String, isFirst: Bool, isLast: Bool,
                              isSelected: Bool) -> UIImage {
            let circleSize: CGFloat = isSelected ? 28 : 22
            let baseSize: CGFloat = isSelected ? 33 : 27
            let tailHeight: CGFloat = isSelected ? 39 : 33
            let circleTopMargin: CGFloat = 4

            let labelFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont, .foregroundColor: UIColor.label
            ]
            let displayName = (name.count > 16 ? String(name.prefix(15)) + "…" : name) as NSString
            let textSize = displayName.size(withAttributes: labelAttributes)
            let labelHeight: CGFloat = 16
            let labelWidth = textSize.width + 16
            let labelSpacing: CGFloat = 3

            let totalWidth = max(baseSize, labelWidth)
            let totalHeight = labelHeight + labelSpacing + tailHeight
            let size = CGSize(width: totalWidth, height: totalHeight)

            return UIGraphicsImageRenderer(size: size).image { ctx in
                let labelRect = CGRect(x: (totalWidth - labelWidth) / 2, y: 0,
                                       width: labelWidth, height: labelHeight)
                let labelPath = UIBezierPath(roundedRect: labelRect, cornerRadius: labelHeight / 2)

                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2,
                                        color: UIColor.black.withAlphaComponent(0.25).cgColor)
                UIColor.systemBackground.setFill()
                labelPath.fill()
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.separator.setStroke()
                ctx.cgContext.setLineWidth(0.5)
                labelPath.stroke()

                displayName.draw(at: CGPoint(x: labelRect.midX - textSize.width / 2,
                                             y: labelRect.midY - textSize.height / 2),
                                 withAttributes: labelAttributes)

                let yOffset = labelHeight + labelSpacing
                let circleRect = CGRect(x: (totalWidth - circleSize) / 2,
                                        y: yOffset + circleTopMargin,
                                        width: circleSize, height: circleSize)

                let fill: UIColor = isFirst ? .systemGreen : isLast ? .systemRed : .systemBlue

                if isSelected {
                    ctx.cgContext.setShadow(offset: .zero, blur: 6,
                                            color: fill.withAlphaComponent(0.6).cgColor)
                    fill.withAlphaComponent(0.25).setFill()
                    ctx.cgContext.fillEllipse(in: circleRect.insetBy(dx: -4, dy: -4))
                    ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                }

                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3,
                                        color: UIColor.black.withAlphaComponent(0.35).cgColor)
                fill.setFill()
                ctx.cgContext.fillEllipse(in: circleRect)

                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(isSelected ? 2.5 : 1.5)
                ctx.cgContext.strokeEllipse(in: circleRect.insetBy(dx: 1, dy: 1))

                let tail = UIBezierPath()
                let midX = totalWidth / 2
                tail.move(to: CGPoint(x: midX - 4.5, y: circleRect.maxY - 2))
                tail.addLine(to: CGPoint(x: midX + 4.5, y: circleRect.maxY - 2))
                tail.addLine(to: CGPoint(x: midX, y: totalHeight - 1))
                tail.close()
                fill.setFill()
                tail.fill()

                let text = "\(number)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: isSelected ? 13 : 11, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let numberSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: circleRect.midX - numberSize.width / 2,
                                      y: circleRect.midY - numberSize.height / 2),
                          withAttributes: attributes)
            }
        }
    }
}
