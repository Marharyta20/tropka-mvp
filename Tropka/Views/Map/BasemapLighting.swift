import MapboxMaps
import SwiftUI

/// How the Mapbox Standard basemap is lit, decided once for every map in the app.
///
/// Both maps used to carry their own copy of this, keyed off the clock: dawn
/// before 8, day until 17, dusk until 21, night after. The idea was nice and the
/// thresholds were fixed, which is the problem — daylight is not. In Warsaw the
/// sun sets around nine in June and around half past three in December, so the
/// map went dusky at five on a bright summer evening and stayed daylit at five
/// in December, hours after dark. Exactly backwards.
///
/// It follows the phone's appearance instead: something the user sets, can
/// change, and which already governs every other screen. A dark map under a
/// light place sheet was the app disagreeing with itself.
///
/// One type rather than two copies, because two copies is how the route map came
/// out of the last change still stuck on the clock while the main map was fixed.
final class BasemapLighting {
    /// What has actually been written to this map. `updateUIView` runs often and
    /// a style-config write is not free.
    private var applied: String?

    func apply(_ scheme: ColorScheme, to mapView: MapboxMaps.MapView) {
        guard mapView.mapboxMap.isStyleLoaded else { return }
        let preset = scheme == .dark ? "night" : "day"
        guard preset != applied else { return }
        applied = preset
        try? mapView.mapboxMap.setStyleImportConfigProperty(
            for: "basemap", config: "lightPreset", value: preset
        )
    }

    /// Call after the style loads or reloads: the import config goes with it, so
    /// what we think is applied is no longer on the map.
    func invalidate() {
        applied = nil
    }
}
