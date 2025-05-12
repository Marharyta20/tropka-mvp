import Foundation
import FirebaseAuth
import Combine

final class AuthViewModel: ObservableObject {
  @Published var isSignedIn = false
  private var handle: AuthStateDidChangeListenerHandle?

  init() {
    handle = AuthService.shared.observeAuthState { [weak self] user in
      DispatchQueue.main.async {
        self?.isSignedIn = (user != nil)
      }
    }
  }
  deinit {
    if let h = handle { AuthService.shared.removeListener(h) }
  }

  func signUp(email: String, password: String) async throws {
    _ = try await AuthService.shared.signUp(email: email, password: password)
  }

  func signIn(email: String, password: String) async throws {
    _ = try await AuthService.shared.signIn(email: email, password: password)
  }

  func signOut() throws {
    try AuthService.shared.signOut()
  }
}
