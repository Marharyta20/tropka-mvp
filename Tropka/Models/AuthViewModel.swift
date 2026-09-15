import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    /// Three states, not two. "We don't know yet" is a real state: reading the
    /// stored session takes a moment, and showing the login screen during that
    /// moment is what makes a signed-in user think they were signed out.
    enum State {
        case checking
        case signedIn
        case signedOut
    }

    @Published var state: State = .checking

    @Published var email = ""
    @Published var password = ""
    @Published var fullName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { state == .signedIn }

    init() {
        // Returning user: re-attach analytics to their id before anything is tracked.
        if let userID = supabase.auth.currentUser?.id.uuidString {
            Analytics.identify(userID: userID)
        }
        listenToAuthChanges()
        Task { await restore() }
    }

    /// Decides the opening screen. A stored session that cannot be refreshed right
    /// now (no signal, airplane mode) still counts as signed in.
    private func restore() async {
        let hasSession = await AuthService.shared.restoreSession()
        if state == .checking {
            state = hasSession ? .signedIn : .signedOut
        }
    }

    private func listenToAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedOut, .userDeleted:
                        self.state = .signedOut
                        // Cleared here rather than in `signOut()` because
                        // `signOut()` is not the only way a session ends:
                        // Settings calls `supabase.auth.signOut()` straight,
                        // Delete Account goes through the Edge Function, and a
                        // refresh can fail on its own. This view model outlives
                        // all three — it is a `@StateObject` on `ContentView`,
                        // which is why the fields survived a sign-out but not a
                        // relaunch — so anything it holds has to be dropped
                        // where the session actually ends.
                        //
                        // What was on screen: sign out, and the login form came
                        // back with the address and the password of the account
                        // that just left. After Delete Account, of an account
                        // that no longer existed.
                        self.clearCredentials()
                    case .tokenRefreshed, .signedIn, .initialSession, .userUpdated, .passwordRecovery:
                        self.state = session != nil ? .signedIn : self.state
                    default:
                        break
                    }
                    // Tie everything the session did to the real user id.
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
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.signUp(email: email, password: password, fullName: fullName)
                // The only path that creates an account which has not been set
                // up. Flipping the flag here means setup appears immediately
                // rather than after `users` has been read back.
                UserPreferences.shared.markNeedsOnboarding()
                Analytics.track(.signedUp)
            } catch {
                Analytics.track(.authFailed, ["mode": "sign_up", "reason": error.localizedDescription])
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
            Analytics.track(.signedOut)
            Analytics.reset()   // next person on this device is a separate user
            state = .signedOut
            clearCredentials()
        }
    }

    /// Everything typed into the login form. Both screens read from here, so
    /// this empties the sign-up fields as well as the log-in ones.
    private func clearCredentials() {
        email = ""
        password = ""
        fullName = ""
    }
}
