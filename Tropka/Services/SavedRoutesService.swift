import Foundation

// MARK: - SavedRoutesService (table: public.saved_routes)

struct SavedRoutesService {

    private var currentUID: String? { supabase.auth.currentUser?.id.uuidString }

    struct SavedRouteInsert: Encodable {
        let userId: String
        let routeId: String
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case routeId = "route_id"
        }
    }

    // MARK: - Save

    func save(routeID: String) async throws {
        guard let uid = currentUID else { throw URLError(.userAuthenticationRequired) }
        let row = SavedRouteInsert(userId: uid, routeId: routeID)
        try await supabase.from("saved_routes").upsert(row).execute()
        await SavedRoutesStore.shared.refresh()
    }

    // MARK: - Remove

    func remove(routeID: String) async throws {
        guard let uid = currentUID else { return }
        try await supabase
            .from("saved_routes")
            .delete()
            .eq("user_id", value: uid)
            .eq("route_id", value: routeID)
            .execute()
        await SavedRoutesStore.shared.refresh()
    }

    // MARK: - Check

    func isSaved(routeID: String) async -> Bool {
        guard let uid = currentUID else { return false }
        struct IDRow: Decodable { let id: String }
        let rows: [IDRow] = (try? await supabase
            .from("saved_routes")
            .select("id")
            .eq("user_id", value: uid)
            .eq("route_id", value: routeID)
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }
}
