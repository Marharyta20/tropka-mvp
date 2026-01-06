import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            // Исправлено: используем isAuthenticated вместо isSignedIn
            if authVM.isAuthenticated {
                MainTabView()
                    .environmentObject(authVM) // Полезно передать authVM дальше, если вдруг понадобится логаут внутри вкладок
            } else {
                LoginView(authVM: authVM)
            }
        }
        // Исправлено: привязываем анимацию к правильной переменной
        .animation(.default, value: authVM.isAuthenticated)
    }
}
