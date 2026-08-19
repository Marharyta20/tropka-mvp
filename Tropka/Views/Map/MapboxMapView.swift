import CoreLocation
import MapboxMaps
import SwiftUI

/// The map behind the Map tab.
///
/// Places that sit on top of each other become a group, drawn as one marker with a
/// count. Tapping a small group spreads its members into a ring around the spot they
/// share, with a line back to the centre — so it is obvious both that they were
/// together and where they really are. Tapping a large group zooms instead: fanning
/// out twenty pins helps nobody.
///
/// Everything else is thinned rather than clustered: labels are given only to places
/// far enough apart to carry one, and the choice is made over the whole city so that
/// panning never changes what is on screen. Zoom does.
struct MapboxMapView: UIViewRepresentable {
    typealias UIViewType = MapboxMaps.MapView

    let places: [Place]
    var onPinTapped: (Place) -> Void
    /// Bumped by the locate button — the value itself is meaningless, the change is
    /// the signal.
    var recenterTrigger: Int
    /// Bumped when a search settles, so the camera can go where the matches are.
    var focusTrigger: Int = 0
    /// Development-only zoom buttons — pinching in the Simulator is painful.
    /// Remove before release; see PRE-RELEASE.md.
    var zoomInTrigger: Int = 0
    var zoomOutTrigger: Int = 0

    /// The app is about Warsaw, so Warsaw is where the map opens.
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
        context.coordinator.focusIfNeeded(trigger: focusTrigger, on: places)
        context.coordinator.zoomIfNeeded(inTrigger: zoomInTrigger, outTrigger: zoomOutTrigger)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, CLLocationManagerDelegate {
        var onPinTapped: ((Place) -> Void)?

        private weak var mapView: MapboxMaps.MapView?
        private var pins: PointAnnotationManager?
        /// The lines from a spread group back to the spot its members share.
        private var legs: PolylineAnnotationManager?
        private var cancelables = Set<AnyCancelable>()
        private var places: [Place] = []

        private var lastRecenterTrigger = 0
        private var lastFocusTrigger = 0
        private var lastZoomInTrigger = 0
        private var lastZoomOutTrigger = 0

        /// Following the user is only useful where there is something to see. Until
        /// the catalogue covers more than one city, a visitor opening the app from
        /// San Francisco should get Warsaw, not an empty map of California — while
        /// someone already in town gets their own street. The locate button
        /// overrides this either way.
        private let locationManager = CLLocationManager()
        private static let warsaw = CLLocation(latitude: 52.2319, longitude: 21.0067)
        private static let cityRadius: CLLocationDistance = 60_000
        private var hasDecidedOpeningCamera = false

        // MARK: Layout state

        private var items: [Item] = []
        private var cachedZoomStep: Int = .min
        /// Re-assigning `annotations` replaces every symbol on the map, which reads as
        /// a blink. Only do it when the picture has actually changed.
        private var renderedSignature = ""
        /// The group currently spread open, if any.
        private var openGroup: Group?

        /// Two places closer than this share a marker. It is a little wider than a
        /// pin, so drawn pins never overlap.
        private let groupRadiusPx: Double = 34
        /// Below this zoom a tapped group is resolved by moving the camera; at or
        /// above it, zooming stops helping and the members are spread instead.
        private static let spreadZoom: CGFloat = 17
        /// How far the members fly out when a group opens.
        private let spreadRadiusPx: CGFloat = 62
        private let maxMarkers = 700

        // MARK: Setup

        func setup(mapView: MapboxMaps.MapView, onPinTapped: @escaping (Place) -> Void) {
            self.mapView = mapView
            self.onPinTapped = onPinTapped
            // Legs go underneath the pins.
            self.legs = mapView.annotations.makePolylineAnnotationManager()

            let pins = mapView.annotations.makePointAnnotationManager()
            // Names are real map labels now: the renderer decides which of them fit,
            // exactly as it does for the basemap's own. `textOptional` is the part
            // that matters — when a name will not fit, the pin still draws, it just
            // loses its caption instead of disappearing.
            pins.iconAllowOverlap = true
            pins.textAllowOverlap = false
            pins.textOptional = true
            pins.textAnchor = .top
            pins.textOffset = [0, 0.9]
            pins.textSize = 11
            pins.textMaxWidth = 8
            pins.textColor = StyleColor(UIColor.label)
            pins.textHaloColor = StyleColor(UIColor.systemBackground)
            pins.textHaloWidth = 1.4
            self.pins = pins

            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self, weak mapView] _ in
                guard let mapView else { return }
                self?.applyLightPreset(to: mapView)
                self?.render()
            }.store(in: &cancelables)

            mapView.mapboxMap.onMapIdle.observe { [weak self] _ in
                self?.render()
            }.store(in: &cancelables)

            // Runs after the annotations have had their say, because an interaction
            // added earlier is invoked later.
            mapView.mapboxMap.addInteraction(TapInteraction { [weak self] context in
                self?.handleMapTap(at: context.point)
                return true
            })

            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        }

        // MARK: Location

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard !hasDecidedOpeningCamera, let location = locations.last else { return }
            hasDecidedOpeningCamera = true
            // Somewhere else entirely: keep the opening view on Warsaw.
            guard location.distance(from: Self.warsaw) <= Self.cityRadius else { return }
            follow(zoom: 13.8)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // No fix — Warsaw stays. Nothing is marked decided, so a later permission
            // grant still gets a chance to move the camera.
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                guard !hasDecidedOpeningCamera else { return }
                manager.requestLocation()
            default:
                break
            }
        }

        private func follow(zoom: CGFloat) {
            guard let mapView else { return }
            let state = mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 120, left: 0, bottom: 220, right: 0),
                    zoom: zoom,
                    bearing: .constant(0),
                    pitch: 0
                )
            )
            mapView.viewport.transition(to: state)
        }

        // MARK: Camera commands

        func update(places: [Place]) {
            guard places.map(\.id) != self.places.map(\.id) else { return }
            self.places = places
            cachedZoomStep = .min
            openGroup = nil
            render()
        }

        func recenterIfNeeded(trigger: Int) {
            guard trigger != lastRecenterTrigger else { return }
            lastRecenterTrigger = trigger
            hasDecidedOpeningCamera = true
            follow(zoom: 14.4)
        }

        /// Filtering the pins is not enough: a search for "Warsaw Uprising Museum"
        /// while the camera sits over Cupertino looks exactly like a search that found
        /// nothing. Move the camera to the matches.
        func focusIfNeeded(trigger: Int, on matches: [Place]) {
            guard trigger != lastFocusTrigger, let mapView else { return }
            lastFocusTrigger = trigger
            guard !matches.isEmpty else { return }

            let coordinates = matches.prefix(60).map(\.coordinates)
            if coordinates.count == 1 {
                mapView.camera.fly(to: CameraOptions(center: coordinates[0], zoom: 16), duration: 0.6)
                return
            }
            if let camera = try? mapView.mapboxMap.camera(
                for: Array(coordinates),
                camera: CameraOptions(bearing: 0, pitch: 0),
                coordinatesPadding: UIEdgeInsets(top: 160, left: 40, bottom: 120, right: 40),
                maxZoom: 16,
                offset: nil
            ) {
                mapView.camera.fly(to: camera, duration: 0.7)
            }
        }

        /// Development-only. Remove with the buttons that drive it.
        func zoomIfNeeded(inTrigger: Int, outTrigger: Int) {
            guard let mapView else { return }
            var delta = 0.0
            if inTrigger != lastZoomInTrigger {
                lastZoomInTrigger = inTrigger
                delta = 1
            }
            if outTrigger != lastZoomOutTrigger {
                lastZoomOutTrigger = outTrigger
                delta = -1
            }
            guard delta != 0 else { return }

            let target = min(max(mapView.mapboxMap.cameraState.zoom + delta, 3), 20)
            mapView.camera.ease(to: CameraOptions(zoom: target), duration: 0.25)
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

        // MARK: Model

        struct Group {
            let id: String
            let coordinate: CLLocationCoordinate2D
            var members: [Place]
        }

        private enum Item {
            case single(Place, labelled: Bool)
            case group(Group)
        }

        // MARK: Rendering

        private func render() {
            guard let mapView, let pins, mapView.mapboxMap.isStyleLoaded, !places.isEmpty else { return }

            let zoom = mapView.mapboxMap.cameraState.zoom
            let step = Int((zoom * 2).rounded())
            if step != cachedZoomStep {
                cachedZoomStep = step
                // Groups are built for a zoom level, so an open one stops making
                // sense the moment that changes.
                openGroup = nil
                items = layout(places, zoom: Double(step) / 2)
            }

            let signature = "\(cachedZoomStep)|\(items.count)|\(places.count)|\(openGroup?.id ?? "-")"
            guard signature != renderedSignature else { return }
            renderedSignature = signature

            var annotations: [PointAnnotation] = []
            var lines: [PolylineAnnotation] = []

            for item in items {
                switch item {
                case let .single(place, labelled):
                    annotations.append(pin(for: place, labelled: labelled))

                case let .group(group):
                    guard group.id == openGroup?.id else {
                        annotations.append(marker(for: group))
                        continue
                    }
                    // Spread: members fly out onto a ring, each keeping a line home.
                    let centre = mapView.mapboxMap.point(for: group.coordinate)
                    for (index, member) in group.members.enumerated() {
                        let angle = (2 * Double.pi / Double(group.members.count)) * Double(index) - .pi / 2
                        // Keep the trigonometry in Double and convert once: mixing it
                        // with the CGFloat radius inline leaves the compiler guessing.
                        let offsetX = CGFloat(cos(angle)) * spreadRadiusPx
                        let offsetY = CGFloat(sin(angle)) * spreadRadiusPx
                        let point = CGPoint(x: centre.x + offsetX, y: centre.y + offsetY)
                        let coordinate = mapView.mapboxMap.coordinate(for: point)

                        var leg = PolylineAnnotation(lineCoordinates: [group.coordinate, coordinate])
                        leg.lineColor = StyleColor(UIColor.label.withAlphaComponent(0.35))
                        leg.lineWidth = 1.5
                        lines.append(leg)

                        annotations.append(pin(for: member, labelled: true, at: coordinate))
                    }
                }
            }

            legs?.annotations = lines
            pins.annotations = annotations
        }

        /// Group what overlaps, then hand out labels to what is left.
        private func layout(_ places: [Place], zoom: Double) -> [Item] {
            let latitude = 52.23 * .pi / 180
            let metresPerPixel = 156_543.03392 * cos(latitude) / pow(2, zoom + 1)

            func metres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
                let dLat = (a.latitude - b.latitude) * 111_320
                let dLng = (a.longitude - b.longitude) * 111_320 * cos(latitude)
                return (dLat * dLat + dLng * dLng).squareRoot()
            }

            let ranked = places.sorted { left, right in
                if left.reviewCount != right.reviewCount { return left.reviewCount > right.reviewCount }
                return left.rating > right.rating
            }

            let groupRadius = groupRadiusPx * metresPerPixel
            var singles: [Place] = []
            var groups: [Group] = []
            // Which bucket each kept spot is, so a third neighbour joins the same one.
            var anchors: [(coordinate: CLLocationCoordinate2D, index: Int, isGroup: Bool)] = []

            for place in ranked {
                guard singles.count + groups.count < maxMarkers else { break }

                if let anchorIndex = anchors.firstIndex(where: { metres(place.coordinates, $0.coordinate) < groupRadius }) {
                    let anchor = anchors[anchorIndex]
                    if anchor.isGroup {
                        groups[anchor.index].members.append(place)
                    } else {
                        // A single that turns out to have company becomes a group.
                        let first = singles[anchor.index]
                        singles.remove(at: anchor.index)
                        // Indices of later singles shift by one.
                        for i in anchors.indices where !anchors[i].isGroup && anchors[i].index > anchor.index {
                            anchors[i].index -= 1
                        }
                        groups.append(Group(id: first.id, coordinate: first.coordinates, members: [first, place]))
                        anchors[anchorIndex] = (first.coordinates, groups.count - 1, true)
                    }
                } else {
                    singles.append(place)
                    anchors.append((place.coordinates, singles.count - 1, false))
                }
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
            // Once the map is this close the pins have already separated, so holding
            // names back only makes the user tap each one to find out what it is.
            let nameEverything = zoom >= 15.5

            var items: [Item] = groups.map { .group($0) }
            for place in singles {
                items.append(.single(place, labelled: nameEverything || place.reviewCount >= nameThreshold))
            }
            return items
        }

        // MARK: Taps

        private func handleMapTap(at point: CGPoint) {
            // A tap anywhere else closes an open group — the same gesture that opened
            // it puts it back.
            if openGroup != nil {
                openGroup = nil
                render()
                return
            }

            guard let mapView else { return }
            let tapRadius: CGFloat = 44

            func distance(to coordinate: CLLocationCoordinate2D) -> CGFloat {
                let p = mapView.mapboxMap.point(for: coordinate)
                return hypot(p.x - point.x, p.y - point.y)
            }

            // Near miss: treat it as a hit on whatever is closest.
            var best: (item: Item, distance: CGFloat)?
            for item in items {
                let coordinate: CLLocationCoordinate2D
                switch item {
                case let .single(place, _): coordinate = place.coordinates
                case let .group(group):     coordinate = group.coordinate
                }
                let d = distance(to: coordinate)
                if d <= tapRadius, d < (best?.distance ?? .greatestFiniteMagnitude) {
                    best = (item, d)
                }
            }

            switch best?.item {
            case let .single(place, _): onPinTapped?(place)
            case let .group(group):     open(group)
            case nil:                   break
            }
        }

        /// Tapping a group always brings it to the middle of the screen.
        ///
        /// While there is room to zoom, that is the answer: the group breaks into
        /// smaller ones on its own, and the result stays readable. Spreading members
        /// onto a ring is reserved for the case zooming cannot fix — places that share
        /// the same doorway — because a ring of pins laid over the neighbours is
        /// exactly the mess it was meant to avoid.
        private func open(_ group: Group) {
            guard let mapView else { return }
            let zoom = mapView.mapboxMap.cameraState.zoom

            guard zoom >= Self.spreadZoom else {
                Analytics.track(.mapZoomed, [
                    "direction": "in",
                    "reason": "group_tapped",
                    "member_count": group.members.count
                ])
                mapView.camera.ease(
                    to: CameraOptions(center: group.coordinate, zoom: min(zoom + 2, Self.spreadZoom)),
                    duration: 0.45
                )
                return
            }

            Analytics.track(.mapGroupOpened, ["member_count": group.members.count])
            // Centre first so the ring has room, then spread.
            mapView.camera.ease(to: CameraOptions(center: group.coordinate), duration: 0.35) { [weak self] _ in
                guard let self else { return }
                self.openGroup = group
                self.render()
            }
        }

        // MARK: Annotations

        private func pin(for place: Place,
                         labelled: Bool,
                         at coordinate: CLLocationCoordinate2D? = nil) -> PointAnnotation {
            var annotation = PointAnnotation(coordinate: coordinate ?? place.coordinates)
            annotation.image = .init(image: Self.pinImage(for: place.category),
                                     name: "pin-\(place.category.rawValue)")
            annotation.iconSize = 0.9
            if labelled {
                annotation.textField = place.name
            }
            annotation.tapHandler = { [weak self] _ in
                self?.onPinTapped?(place)
                return true
            }
            return annotation
        }

        private func marker(for group: Group) -> PointAnnotation {
            var annotation = PointAnnotation(coordinate: group.coordinate)
            annotation.image = .init(image: Self.groupImage(count: group.members.count,
                                                            categories: group.members.map(\.category)),
                                     name: "group-\(group.members.count)-\(group.members.first?.category.rawValue ?? 0)")
            annotation.tapHandler = { [weak self] _ in
                self?.open(group)
                return true
            }
            return annotation
        }

        // MARK: Images

        /// A group looks like a group: bigger than a pin, ringed in white, wearing the
        /// count. Nothing about it should read as a single place.
        private static func groupImage(count: Int, categories: [PlaceCategory]) -> UIImage {
            let diameter: CGFloat = count > 6 ? 44 : 38
            let size = CGSize(width: diameter, height: diameter)
            let tint = categories.first?.color ?? .systemBlue

            return UIGraphicsImageRenderer(size: size).image { context in
                let rect = CGRect(origin: .zero, size: size)

                tint.withAlphaComponent(0.25).setFill()
                context.cgContext.fillEllipse(in: rect)

                context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3,
                                            color: UIColor.black.withAlphaComponent(0.35).cgColor)
                tint.setFill()
                context.cgContext.fillEllipse(in: rect.insetBy(dx: 5, dy: 5))
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

                UIColor.white.setStroke()
                context.cgContext.setLineWidth(2)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 5, dy: 5))

                let text = "\(count)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: count > 9 ? 14 : 15, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: rect.midX - textSize.width / 2,
                                      y: rect.midY - textSize.height / 2),
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
                    icon.draw(in: CGRect(x: rect.midX - icon.size.width / 2,
                                         y: rect.midY - icon.size.height / 2,
                                         width: icon.size.width,
                                         height: icon.size.height))
                }
            }
        }
    }
}
