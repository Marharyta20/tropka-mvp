import CoreLocation
import MapboxMaps
import SwiftUI

/// The map behind the Map tab.
///
/// It does not cluster. A circle reading "999+" answers a question nobody asked —
/// what matters on a city map is *which* places are here, not how many. Instead the
/// map thins: at each zoom level it keeps the most notable places that fit without
/// overlapping, and reveals the quieter ones as you come closer.
///
/// The thinning is done over the whole city, not over what is currently on screen.
/// That matters: a selection that depends on the viewport changes every time the map
/// moves, so a pin you are panning towards can vanish just as it reaches the middle
/// of the screen. Zoom changes the picture; panning never does.
struct MapboxMapView: UIViewRepresentable {
    typealias UIViewType = MapboxMaps.MapView

    let places: [Place]
    var onPinTapped: (Place) -> Void
    /// Bumped by the locate button — the value itself is meaningless, the change is
    /// the signal.
    var recenterTrigger: Int

    /// Warsaw, so the first frame is a city rather than a globe.
    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 52.2319, longitude: 21.0067)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let options = MapInitOptions(
            cameraOptions: CameraOptions(center: Self.fallbackCenter, zoom: 12.5),
            styleURI: .standard
        )
        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: options)

        mapView.location.options.puckType = .puck2D()
        mapView.location.options.puckBearing = .heading
        mapView.location.options.puckBearingEnabled = true

        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.compassView.isHidden = false
        // Mapbox puts the attribution "i" at bottom-trailing by default — directly
        // under our locate button, so aiming for one hits the other. It cannot be
        // hidden (Mapbox and OpenStreetMap both require it), but it can move: park
        // it next to the logo in the opposite corner.
        mapView.ornaments.options.attributionButton.position = .bottomLeading
        mapView.ornaments.options.attributionButton.margins = CGPoint(x: 100, y: 8)
        // Tilting is what turns the Standard style's buildings into 3D.
        mapView.gestures.options.pitchEnabled = true

        context.coordinator.setup(mapView: mapView, onPinTapped: onPinTapped)
        return mapView
    }

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        context.coordinator.onPinTapped = onPinTapped
        context.coordinator.update(places: places)
        context.coordinator.recenterIfNeeded(trigger: recenterTrigger)
    }

    // MARK: - Coordinator

    final class Coordinator {
        var onPinTapped: ((Place) -> Void)?

        private weak var mapView: MapboxMaps.MapView?
        private var manager: PointAnnotationManager?
        private var cancelables = Set<AnyCancelable>()
        private var places: [Place] = []
        private var lastRecenterTrigger = 0

        /// The chosen set only changes with zoom, so it is worth keeping.
        private var cachedSelection: [Selection] = []
        private var cachedZoomStep: Int = .min

        /// The footprint each pin claims, in points — roughly its drawn width. Two
        /// pins may sit as close as the average of their footprints, so a plain dot
        /// next to a named pin is not pushed away by the label's full width.
        private let plainSpacingPx: Double = 36
        private let labelledSpacingPx: Double = 105
        /// Thinning runs over the whole city, so the cap is a safety net for zoom
        /// levels where almost everything survives.
        private let maxPins = 400

        func setup(mapView: MapboxMaps.MapView, onPinTapped: @escaping (Place) -> Void) {
            self.mapView = mapView
            self.onPinTapped = onPinTapped
            self.manager = mapView.annotations.makePointAnnotationManager()

            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self, weak mapView] _ in
                guard let mapView else { return }
                self?.applyLightPreset(to: mapView)
                self?.render()
            }.store(in: &cancelables)

            // Redraw once the camera settles. Panning reuses the cached selection, so
            // the pins stay exactly where they were.
            mapView.mapboxMap.onMapIdle.observe { [weak self] _ in
                self?.render()
            }.store(in: &cancelables)

            // ~1.3 km across a phone screen: close enough to recognise the street
            // you are on, wide enough to see where the neighbourhood goes. The
            // previous 14.5 showed about 800 m, which read as "already zoomed in".
            let follow = mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 120, left: 0, bottom: 220, right: 0),
                    zoom: 13.8,
                    bearing: .constant(0),
                    pitch: 0
                )
            )
            mapView.viewport.transition(to: follow)
        }

        // MARK: Style

        /// Warsaw at 22:00 should not look like Warsaw at noon.
        private func applyLightPreset(to mapView: MapboxMaps.MapView) {
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

        // MARK: Data

        func update(places: [Place]) {
            guard places.map(\.id) != self.places.map(\.id) else { return }
            self.places = places
            cachedZoomStep = .min
            render()
        }

        func recenterIfNeeded(trigger: Int) {
            guard trigger != lastRecenterTrigger, let mapView else { return }
            lastRecenterTrigger = trigger
            // Pressing the button is a deliberate "where am I", so it lands closer
            // than the opening view.
            let follow = mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 120, left: 0, bottom: 220, right: 0),
                    zoom: 14.4,
                    bearing: .constant(0),
                    pitch: 0
                )
            )
            mapView.viewport.transition(to: follow)
        }

        // MARK: Rendering

        private func render() {
            guard let mapView, let manager, mapView.mapboxMap.isStyleLoaded, !places.isEmpty else { return }

            let zoom = mapView.mapboxMap.cameraState.zoom
            // Half-zoom steps: fine enough to feel responsive, coarse enough that the
            // set does not churn while the camera settles.
            let step = Int((zoom * 2).rounded())
            if step != cachedZoomStep {
                cachedZoomStep = step
                cachedSelection = thin(places, zoom: Double(step) / 2)
            }

            manager.annotations = cachedSelection.map { selection in
                annotation(for: selection.place, labelled: selection.labelled)
            }
        }

        private struct Selection {
            let place: Place
            let labelled: Bool
        }

        /// Rank by how well known a place is, then walk the list keeping anything that
        /// does not land on top of something already kept.
        ///
        /// Distances are compared in metres, not in degrees. Mapbox tiles are 512px
        /// wide, and Mercator stretches a degree of latitude by 1/cos(latitude) — get
        /// either wrong and the spacing silently triples, which leaves a city-wide
        /// view with five pins on it.
        private func thin(_ places: [Place], zoom: Double) -> [Selection] {
            let latitude = 52.23 * .pi / 180
            let metresPerPixel = 156_543.03392 * cos(latitude) / pow(2, zoom + 1)

            func metres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
                let dLat = (a.latitude - b.latitude) * 111_320
                let dLng = (a.longitude - b.longitude) * 111_320 * cos(latitude)
                return (dLat * dLat + dLng * dLng).squareRoot()
            }

            // How famous a place must be to carry its name. Pulled back as the user
            // zooms out, so the overview reads "Palace of Culture, Łazienki, Old Town"
            // rather than a field of anonymous dots.
            let nameThreshold: Int
            switch zoom {
            case ..<12:     nameThreshold = 6000
            case 12..<13.5: nameThreshold = 3000
            case 13.5..<15: nameThreshold = 800
            default:        nameThreshold = 250
            }

            let ranked = places.sorted { left, right in
                if left.reviewCount != right.reviewCount { return left.reviewCount > right.reviewCount }
                return left.rating > right.rating
            }

            var kept: [Selection] = []
            for place in ranked {
                guard kept.count < maxPins else { break }
                let labelled = place.reviewCount >= nameThreshold
                let spacing = (labelled ? labelledSpacingPx : plainSpacingPx) * metresPerPixel

                let collides = kept.contains { other in
                    let otherSpacing = (other.labelled ? labelledSpacingPx : plainSpacingPx) * metresPerPixel
                    // Half-sum, not max: two footprints overlap when the gap is
                    // smaller than their average width. Taking the max let one named
                    // pin clear a kilometre of map around itself.
                    return metres(place.coordinates, other.place.coordinates) < (spacing + otherSpacing) / 2
                }
                if !collides {
                    kept.append(Selection(place: place, labelled: labelled))
                }
            }
            return kept
        }

        private func annotation(for place: Place, labelled: Bool) -> PointAnnotation {
            var annotation = PointAnnotation(coordinate: place.coordinates)
            if labelled {
                annotation.image = .init(image: Self.labelledPin(for: place),
                                         name: "labelled-\(place.id)")
                annotation.iconAnchor = .top
            } else {
                annotation.image = .init(image: Self.pinImage(for: place.category),
                                         name: "pin-\(place.category.rawValue)")
                annotation.iconSize = 0.9
            }
            annotation.tapHandler = { [weak self] _ in
                self?.onPinTapped?(place)
                return true
            }
            return annotation
        }

        // MARK: Images

        /// A category dot with the place's name underneath, in the same visual
        /// language the basemap uses for its own landmarks.
        private static func labelledPin(for place: Place) -> UIImage {
            let dot = pinImage(for: place.category)
            let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: UIColor.label
            ]
            let name = (place.name.count > 22 ? String(place.name.prefix(21)) + "…" : place.name) as NSString
            let textSize = name.size(withAttributes: attributes)

            let padding: CGFloat = 6
            let labelWidth = textSize.width + padding * 2
            let labelHeight = textSize.height + 4
            let width = max(dot.size.width, labelWidth)
            let height = dot.size.height + 3 + labelHeight

            return UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
                dot.draw(at: CGPoint(x: (width - dot.size.width) / 2, y: 0))

                let labelRect = CGRect(x: (width - labelWidth) / 2,
                                       y: dot.size.height + 3,
                                       width: labelWidth,
                                       height: labelHeight)
                let path = UIBezierPath(roundedRect: labelRect, cornerRadius: labelHeight / 2)
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2,
                                            color: UIColor.black.withAlphaComponent(0.2).cgColor)
                UIColor.systemBackground.withAlphaComponent(0.95).setFill()
                path.fill()
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

                name.draw(at: CGPoint(x: labelRect.midX - textSize.width / 2,
                                      y: labelRect.midY - textSize.height / 2),
                          withAttributes: attributes)
            }
        }

        private static func pinImage(for category: PlaceCategory) -> UIImage {
            let size = CGSize(width: 28, height: 28)
            return UIGraphicsImageRenderer(size: size).image { context in
                let rect = CGRect(origin: .zero, size: size)

                context.cgContext.setShadow(offset: CGSize(width: 0, height: 1),
                                            blur: 2,
                                            color: UIColor.black.withAlphaComponent(0.3).cgColor)
                category.color.setFill()
                context.cgContext.fillEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

                UIColor.white.setStroke()
                context.cgContext.setLineWidth(1.5)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))

                let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
                if let icon = UIImage(systemName: category.icon, withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    icon.draw(in: CGRect(x: (size.width - icon.size.width) / 2,
                                         y: (size.height - icon.size.height) / 2,
                                         width: icon.size.width,
                                         height: icon.size.height))
                }
            }
        }
    }
}
