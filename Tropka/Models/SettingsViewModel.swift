import Supabase
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var error: String?

    /// What the database held when the screen opened. Kept so the Save button
    /// can tell an edit from a glance: it used to be enabled the moment the
    /// screen loaded, and saving an unchanged profile reported "Changes saved"
    /// for a write that changed nothing.
    private var loadedName = ""

    var hasChanges: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines) != loadedName
    }
    @Published var isBusy = false
    /// Nothing may be saved before the current values have been read: saving a
    /// field the user never saw would overwrite their profile with a blank.
    @Published var isLoaded = false

    /// Shown, not edited. Changing an email address means re-verifying it, which
    /// is a flow of its own; not showing it at all left people unable to tell
    /// which of their two accounts they were signed in to.
    var email: String { supabase.auth.currentUser?.email ?? "" }

    /// Reads Info.plist rather than a constant, so it cannot drift from the
    /// build somebody is actually reporting a problem about.
    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    init() { Task { await load() } }

    // MARK: - Load

    func load() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        struct UserRow: Decodable {
            let fullName: String?
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
            }
        }

        do {
            let row: UserRow = try await supabase
                .from("users")
                .select("full_name")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            displayName = row.fullName ?? ""
            loadedName = displayName
            isLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    /// Returns whether the write actually reached the database. The caller used
    /// to show "Changes saved" unconditionally and copy the new values into the
    /// profile header, so a failed save looked like a successful one and the
    /// screen disagreed with the server until the next launch.
    @discardableResult
    func save() async -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLoaded, !name.isEmpty else {
            error = "Your name can't be empty."
            return false
        }
        isBusy = true
        defer { isBusy = false }

        struct UserUpdate: Encodable {
            let fullName: String
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
            }
        }

        do {
            try await supabase
                .from("users")
                .update(UserUpdate(fullName: name))
                .eq("id", value: uid)
                .execute()
            // Write back the trimmed value, so the field shows what was stored
            // and the button goes quiet again.
            displayName = name
            loadedName = name
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Password

    /// Changing a password you know, as opposed to recovering one you forgot.
    /// The app had only the second, so the ordinary case went through an email
    /// round trip for no reason.
    ///
    /// Supabase does not ask for the current password here — the session is the
    /// proof. It is still required on screen: a phone left unlocked on a table
    /// should not be one tap away from a new password.
    @discardableResult
    func changePassword(current: String, new: String) async -> Bool {
        guard let email = supabase.auth.currentUser?.email else {
            error = "Not signed in."
            return false
        }
        guard new.count >= 6 else {
            error = "The new password must be at least 6 characters."
            return false
        }
        isBusy = true
        defer { isBusy = false }

        do {
            // Verified by signing in with it rather than trusted.
            try await supabase.auth.signIn(email: email, password: current)
        } catch {
            self.error = "That is not your current password."
            return false
        }

        do {
            try await AuthService.shared.updatePassword(new)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task { try? await supabase.auth.signOut() }
    }

    // MARK: - Delete Account

    /// Deleting an auth user needs the service role key, which must never ship
    /// inside the app, so this goes through the `delete-account` Edge Function.
    /// The function resolves the caller from their own token — it can only ever
    /// delete the person asking — and `users.id` now cascades from `auth.users`,
    /// so the profile, routes, reviews and saved routes go with it.
    ///
    /// The previous version deleted only the profile row. The login still worked
    /// afterwards, nothing recreated the profile, and the account came back
    /// permanently unusable.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard supabase.auth.currentUser != nil else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            try await supabase.functions.invoke("delete-account")
            // The account is gone; a failure to tear down the local session is
            // not worth reporting on top of that.
            try? await supabase.auth.signOut()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - Legal

/// The App Store requires a reachable privacy policy for any app with accounts,
/// and reviewers look for it inside the app as well as in App Store Connect.
///
/// TODO before submission: replace with the real published URLs.
enum Legal {
    static let privacyPolicy = URL(string: "https://tropka.app/privacy")!
    static let terms = URL(string: "https://tropka.app/terms")!
    static let support = URL(string: "mailto:hello@tropka.app")!
}
