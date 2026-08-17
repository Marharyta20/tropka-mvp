import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                MainTabView()
                    .environmentObject(authVM) // Passed down so tabs can trigger sign-out
            } else {
                LoginView(authVM: authVM)
            }
        }
        .animation(.default, value: authVM.isAuthenticated)
    }
}
