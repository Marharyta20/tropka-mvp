import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

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
