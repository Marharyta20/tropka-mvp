import MapboxNavigationCore
import MapboxNavigationUIKit

/// Single source of truth for Mapbox Navigation.
/// MapboxNavigationProvider must exist exactly once per app lifecycle.
@MainActor
final class NavigationContainer {
    static let shared = NavigationContainer()

    let provider: MapboxNavigationProvider

    /// Lazily built NavigationOptions that reuses the existing provider —
    /// avoids the "MapboxNavigationProvider was instantiated twice" crash.
    private(set) lazy var navigationOptions: NavigationOptions = {
        NavigationOptions(
            mapboxNavigation: provider.mapboxNavigation,
            voiceController: provider.routeVoiceController,
            eventsManager: provider.eventsManager()
        )
    }()

    private init() {
        provider = MapboxNavigationProvider(coreConfig: .init())
    }
}
