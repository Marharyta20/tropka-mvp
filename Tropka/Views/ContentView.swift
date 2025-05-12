import SwiftUI

struct ContentView: View {
  @StateObject private var authVM = AuthViewModel()

  var body: some View {
    Group {
        if authVM.isSignedIn {
          MainTabView()
        } else {
          LoginView(authVM: authVM)
        }
    }
    .animation(.default, value: authVM.isSignedIn)
  }
}
