import Foundation
import Supabase

// MARK: - AuthService (Supabase Auth)

final class AuthService {
    static let shared = AuthService()
    private init() {}

    var currentUserID: String? {
        supabase.auth.currentUser?.id.uuidString
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, fullName: String) async throws {
        let response = try await supabase.auth.signUp(email: email, password: password)
        let user = response.user

        // Email is deliberately not stored in public.users: it lives in auth.users
        // and is reachable client-side as supabase.auth.currentUser?.email. Keeping
        // it out is what lets the profile table stay readable by every signed-in
        // user (needed to show a review's author) without leaking addresses.
        struct UserInsert: Encodable {
            let id: String
            let fullName: String
            let username: String
            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
            }
        }

        // The generated handle is never shown and never asked for: `username`
        // is `UNIQUE` in `public.users` and route cards fall back to it when a
        // name is blank. It stays as plumbing until profiles become public and
        // a handle is something the user chooses on purpose.
        //
        // Derived from the account id rather than random. The old
        // `user<1000...9999>` drew from 9000 values against a UNIQUE column,
        // which by the birthday bound starts colliding around the hundredth
        // account — and sign-up would have failed with a constraint violation
        // for a field the user never filled in and, since the handle left
        // Settings, can no longer change.
        let profile = UserInsert(
            id: user.id.uuidString,
            fullName: fullName,
            username: "user_" + user.id.uuidString.prefix(8).lowercased()
        )
        try await supabase.from("users").upsert(profile).execute()
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Password recovery

    /// Sends the six-digit recovery code to the address.
    ///
    /// Deliberately not a magic link: a link drags the user out to Safari and back,
    /// needs a URL scheme and a redirect allow-list, and breaks entirely if the mail
    /// is read on a different device. A code can be typed anywhere.
    func sendRecoveryCode(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    /// Exchanges the code for a session. From here the user is signed in and may
    /// set a new password — that is how Supabase's recovery flow works.
    func verifyRecoveryCode(email: String, code: String) async throws {
        try await supabase.auth.verifyOTP(email: email, token: code, type: .recovery)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
    }

    // MARK: - Session

    /// Refreshes the stored session and reports whether it is still valid.
    ///
    /// A thrown error is *not* the same as "signed out": no network means we cannot
    /// tell, and dropping the user to the login screen because their train went into
    /// a tunnel is the bug this exists to avoid. Only `sessionMissing` is an answer.
    func restoreSession() async -> Bool {
        if supabase.auth.currentSession == nil { return false }
        do {
            _ = try await supabase.auth.session
            return true
        } catch let error as AuthError {
            if case .sessionMissing = error { return false }
            return true
        } catch {
            return true
        }
    }
}
