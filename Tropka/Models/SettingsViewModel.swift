import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var username = ""
    @Published var error: String?
    @Published var isBusy = false
    /// Nothing may be saved before the current values have been read: saving a
    /// field the user never saw would overwrite their profile with a blank.
    @Published var isLoaded = false

    init() { Task { await load() } }

    // MARK: - Load

    func load() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        struct UserRow: Decodable {
            let fullName: String?
            let username: String?
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
            }
        }

        do {
            let row: UserRow = try await supabase
                .from("users")
                .select("full_name, username")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            displayName = row.fullName ?? ""
            username    = row.username ?? ""
            isLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    func save() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLoaded, !name.isEmpty, !handle.isEmpty else {
            error = "Name and username can't be empty."
            return
        }
        isBusy = true
        defer { isBusy = false }

        struct UserUpdate: Encodable {
            let fullName: String
            let username: String
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
            }
        }

        do {
            try await supabase
                .from("users")
                .update(UserUpdate(fullName: name, username: handle))
                .eq("id", value: uid)
                .execute()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task { try? await supabase.auth.signOut() }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await supabase.from("users").delete().eq("id", value: uid).execute()
            try await supabase.auth.signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

}
