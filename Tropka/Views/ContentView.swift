import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Group {
            switch authVM.state {
            case .checking:
                // Reading the stored session is not instant. Showing the login form
                // during that moment is what made returning users believe they had
                // been signed out — and type their password again.
                launchScreen
            case .signedIn:
                MainTabView()
                    .environmentObject(authVM) // Passed down so tabs can trigger sign-out
            case .signedOut:
                LoginView(authVM: authVM)
            }
        }
        .animation(.default, value: authVM.state)
        // Presented from the root rather than from the tab view: SwiftUI warns
        // about reparenting when a cover is attached to a TabView, and routing
        // belongs here anyway.
        //
        // A cover rather than a fourth branch of the switch: a returning user
        // never sees a flicker of setup while the flag is still being read, and
        // a new account gets it the moment sign-up succeeds.
        .fullScreenCover(isPresented: Binding(
            get: { authVM.state == .signedIn && preferences.needsOnboarding },
            set: { _ in })
        ) {
            OnboardingView {
                Task { await preferences.refresh() }
            }
        }
    }

    private var launchScreen: some View {
        VStack(spacing: 14) {
            Text("Tropka")
                .font(.largeTitle.bold())
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
