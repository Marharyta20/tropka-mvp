import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var fullName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    init() {
        isAuthenticated = supabase.auth.currentSession != nil
        // Returning user: re-attach analytics to their id before anything else is tracked.
        if let userID = supabase.auth.currentUser?.id.uuidString {
            Analytics.identify(userID: userID)
        }
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isAuthenticated = session != nil
                    // Tie everything the anonymous session did to the real user id.
                    if let userID = session?.user.id.uuidString {
                        Analytics.identify(userID: userID)
                    }
                }
            }
        }
    }

    // MARK: - Register

    func register() {
        guard !email.isEmpty, !password.isEmpty, !fullName.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.signUp(email: email, password: password, fullName: fullName)
                Analytics.track(.signedUp)
            } catch {
                Analytics.track(.authFailed, ["mode": "sign_up", "reason": error.localizedDescription])
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Login

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.signIn(email: email, password: password)
                Analytics.track(.loggedIn)
            } catch {
                Analytics.track(.authFailed, ["mode": "log_in", "reason": error.localizedDescription])
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
            Analytics.track(.signedOut)
            Analytics.reset()   // next person on this device is a separate user
            await MainActor.run {
                self.isAuthenticated = false
                self.email = ""
                self.password = ""
                self.fullName = ""
            }
        }
    }
}
