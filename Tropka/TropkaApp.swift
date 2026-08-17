import SwiftUI

@main
struct TropkaApp: App {

    init() {
        Analytics.start()
    }

    var body: some Scene {
        WindowGroup {
            // No NavigationStack here on purpose: every screen that needs one
            // declares its own (Explore, Profile, Tips, the editor…). Wrapping the
            // whole TabView in a second stack put an outer navigation bar above
            // the inner ones, which swallowed their toolbars — that is why the
            // "+" button on Explore never showed up.
            ContentView()
        }
    }
}
