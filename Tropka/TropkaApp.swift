import SwiftUI

@main
struct TropkaApp: App {

    /// SwiftUI exposes no hook for the two APNs callbacks, so an adaptor carries
    /// the smallest delegate that can receive a device token.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Analytics.start()
        // Registers for a token if permission already exists. Never prompts —
        // the prompt is shown where it means something, not at launch.
        PushService.shared.start()
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
