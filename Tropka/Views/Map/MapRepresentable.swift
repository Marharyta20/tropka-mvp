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
        // Draws a numbered circle with a pointer tail anchored to the exact
        // coordinate (same geometry as before) plus a small name-tag pill
        // above it. Baking the name into the bitmap avoids it colliding with
        // the basemap's own street/place labels, which a separate Mapbox
        // text symbol would be prone to.
        func numberedPinImage(number: Int, name: String, isFirst: Bool, isLast: Bool,
                              isSelected: Bool = false) -> UIImage {
            let baseSize: CGFloat = isSelected ? 33 : 27
            let circleSize: CGFloat = isSelected ? 28 : 22
            let tailH: CGFloat = isSelected ? 39 : 33 // height of circle+tail region only
            let circleTopMargin: CGFloat = 4

            let labelFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor.label]
            let displayName = name.count > 16 ? String(name.prefix(15)) + "…" : name
            let displayNameNS = displayName as NSString
            let textSize = displayNameNS.size(withAttributes: labelAttrs)
            let labelHPadding: CGFloat = 8
            let labelHeight: CGFloat = 16
            let labelWidth = textSize.width + labelHPadding * 2
            let labelSpacing: CGFloat = 3

            let totalWidth = max(baseSize, labelWidth)
            let totalHeight = labelHeight + labelSpacing + tailH
            let size = CGSize(width: totalWidth, height: totalHeight)

            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                // --- Name tag pill (top) ---
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

                let textOrigin = CGPoint(x: labelRect.midX - textSize.width / 2,
                                         y: labelRect.midY - textSize.height / 2)
                displayNameNS.draw(at: textOrigin, withAttributes: labelAttrs)

                // --- Circle + tail (below the label) ---
                let yOffset = labelHeight + labelSpacing
                let cx = (totalWidth - circleSize) / 2
                let circleRect = CGRect(x: cx, y: yOffset + circleTopMargin,
                                        width: circleSize, height: circleSize)

                let fillColor: UIColor = isFirst ? .systemGreen
                                       : isLast  ? .systemRed
                                                 : .systemBlue

                // Outer glow ring for selected
                if isSelected {
                    ctx.cgContext.setShadow(offset: .zero, blur: 6,
                                           color: fillColor.withAlphaComponent(0.6).cgColor)
                    fillColor.withAlphaComponent(0.25).setFill()
                    ctx.cgContext.fillEllipse(in: circleRect.insetBy(dx: -4, dy: -4))
                    ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                }

                // Shadow
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5),
                                        blur: 3,
                                        color: UIColor.black.withAlphaComponent(0.35).cgColor)
                fillColor.setFill()
                ctx.cgContext.fillEllipse(in: circleRect)

                // White border
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(isSelected ? 2.5 : 1.5)
                ctx.cgContext.strokeEllipse(in: circleRect.insetBy(dx: 1, dy: 1))

                // Triangle tail — its tip is the exact anchored coordinate
                let tailPath = UIBezierPath()
                let midX = totalWidth / 2
                let circleBottom = circleRect.maxY
                tailPath.move(to: CGPoint(x: midX - 4.5, y: circleBottom - 2))
                tailPath.addLine(to: CGPoint(x: midX + 4.5, y: circleBottom - 2))
                tailPath.addLine(to: CGPoint(x: midX, y: totalHeight - 1))
                tailPath.close()
                fillColor.setFill()
                tailPath.fill()

                // Number
                let text = "\(number)" as NSString
                let fontSize: CGFloat = isSelected ? 13 : 11
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let numberSize = text.size(withAttributes: attrs)
                let numberRect = CGRect(
                    x: circleRect.midX - numberSize.width / 2,
                    y: circleRect.midY - numberSize.height / 2,
                    width: numberSize.width, height: numberSize.height)
                text.draw(in: numberRect, withAttributes: attrs)
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

            // --- PINS with custom numbered images (name baked in above the pin) ---
            let totalStops = parent.stops.count
            let selectedIdx = parent.selectedStopIndex
            let points: [PointAnnotation] = parent.stops.enumerated().map { index, stop in
                let isFirst    = index == 0
                let isLast     = index == totalStops - 1
                let isSelected = index == selectedIdx
                let pinImage   = numberedPinImage(number: index + 1,
                                                  name: stop.name,
                                                  isFirst: isFirst,
                                                  isLast: isLast,
                                                  isSelected: isSelected)
                let imageID = "pin-\(index + 1)-\(isSelected ? "sel" : isFirst ? "start" : isLast ? "end" : "mid")"
                try? mapView.mapboxMap.addImage(pinImage, id: imageID)

                var annotation = PointAnnotation(coordinate: stop.location)
                annotation.iconImage = imageID
                annotation.iconAnchor = .bottom
                annotation.iconSize = 1.0
                return annotation
            }
            pointManager.annotations = points

            // --- ROUTE LINE (white casing underneath for legibility over any basemap) ---
            let lineCoords = !parent.routeCoords.isEmpty
                ? parent.routeCoords
                : parent.stops.map { $0.location }

            if lineCoords.count > 1 {
                var casing = PolylineAnnotation(lineCoordinates: lineCoords)
                casing.lineColor = StyleColor(UIColor.white)
                casing.lineWidth = 8.0
                casing.lineOpacity = 0.9

                var polyline = PolylineAnnotation(lineCoordinates: lineCoords)
                polyline.lineColor = StyleColor(UIColor.systemBlue)
                polyline.lineWidth = 5.0
                polyline.lineOpacity = 0.95

                polylineManager.annotations = [casing, polyline]
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
        let myMapInitOptions = MapInitOptions(styleURI: .standard)
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
