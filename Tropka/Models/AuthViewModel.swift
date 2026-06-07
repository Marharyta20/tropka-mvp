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
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isAuthenticated = session != nil
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
            } catch {
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
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.email = ""
                self.password = ""
                self.fullName = ""
            }
        }
    }
}
