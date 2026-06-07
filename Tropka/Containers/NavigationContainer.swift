import MapboxNavigationCore

@MainActor
final class NavigationContainer {
    static let shared = NavigationContainer()
    let provider: MapboxNavigationProvider
    private init() {
        provider = MapboxNavigationProvider(coreConfig: .init())
    }
}
