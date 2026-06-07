import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var username = ""
    @Published var error: String?
    @Published var isBusy = false

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
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    func save() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
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
                .update(UserUpdate(fullName: displayName, username: username))
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

    func prefill(with p: ProfileViewModel) {
        displayName = p.displayName
        username    = p.handle
    }
}
