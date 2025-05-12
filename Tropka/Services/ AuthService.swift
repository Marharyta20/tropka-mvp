import FirebaseAuth

final class AuthService {
  static let shared = AuthService()
  private init() {}

  func signUp(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)
    return result.user
  }

  func signIn(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().signIn(withEmail: email, password: password)
    return result.user
  }

  func signOut() throws {
    try Auth.auth().signOut()
  }

  func observeAuthState(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
    return Auth.auth().addStateDidChangeListener { _, user in
      listener(user)
    }
  }

  func removeListener(_ handle: AuthStateDidChangeListenerHandle) {
    Auth.auth().removeStateDidChangeListener(handle)
  }
}
