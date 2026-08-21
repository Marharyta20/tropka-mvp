import Foundation
import Combine

// MARK: - SavedRoutesStore
// Maintains the set of saved route IDs for the current user.
// Call refresh() after any save/remove operation.

@MainActor
final class SavedRoutesStore: ObservableObject {
    static let shared = SavedRoutesStore()

    @Published private(set) var savedIDs: Set<String> = []

    private init() {
        Task { await refresh() }

        // Re-fetch whenever auth state changes
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if session != nil {
                    await refresh()
                } else {
                    savedIDs = []
                }
            }
        }
    }

    func refresh() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            savedIDs = []
            return
        }

        struct IDRow: Decodable {
            let routeId: String
            enum CodingKeys: String, CodingKey { case routeId = "route_id" }
        }

        do {
            let rows: [IDRow] = try await supabase
                .from("saved_routes")
                .select("route_id")
                .eq("user_id", value: uid)
                .execute()
                .value
            savedIDs = Set(rows.map(\.routeId))
        } catch {
            // Keep whatever we already know. Clearing the set on a network failure
            // unfilled every bookmark in Explore and hid the review button on a
            // route the user had definitely saved.
            print("SavedRoutesStore: refresh failed:", error)
        }
    }
}
