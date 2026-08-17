import SwiftUI

@main
struct TropkaApp: App {

    init() {
        Analytics.start()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
