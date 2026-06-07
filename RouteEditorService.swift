import Foundation

// MARK: - RouteEditorService (Supabase)

struct RouteEditorService {

    private var currentUID: String? { supabase.auth.currentUser?.id.uuidString }

    // MARK: - Row types

    private struct RouteInsert: Encodable {
        let authorUid: String
        let title: String
        let tags: [String]
        let price: Double?
        let thumbnailUrl: String?
        let stopsCount: Int
        let duration: Int       // minutes
        let isFree: Bool
        let rating: Double
        let reviewCount: Int

        enum CodingKeys: String, CodingKey {
            case authorUid   = "author_uid"
            case title, tags, price
            case thumbnailUrl = "thumbnail_url"
            case stopsCount  = "stops_count"
            case duration
            case isFree      = "is_free"
            case rating
            case reviewCount = "review_count"
        }
    }

    private struct RouteStopInsert: Encodable {
        let routeId: String
        let placeId: Int?       // nil when stop is not yet a known Place in the DB
        let orderIndex: Int
        let notes: String?
        let photoUrl: String?
        let timeSpent: Int

        enum CodingKeys: String, CodingKey {
            case routeId    = "route_id"
            case placeId    = "place_id"
            case orderIndex = "order_index"
            case notes
            case photoUrl   = "photo_url"
            case timeSpent  = "time_spent"
        }
    }

    // MARK: - Create

    func createRoute(title: String, tags: [String], price: Double?, thumbnailURL: URL?, stops: [Stop]) async throws -> String {
        guard let uid = currentUID else { throw URLError(.userAuthenticationRequired) }

        let totalMinutes = stops.reduce(0) { $0 + max(0, $1.timeSpent) }

        let row = RouteInsert(
            authorUid: uid,
            title: title,
            tags: tags,
            price: price,
            thumbnailUrl: thumbnailURL?.absoluteString,
            stopsCount: stops.count,
            duration: totalMinutes,
            isFree: price == nil || (price ?? 0) == 0,
            rating: 0,
            reviewCount: 0
        )

        struct IDRow: Decodable { let id: String }
        let result: IDRow = try await supabase
            .from("routes")
            .insert(row)
            .select("id")
            .single()
            .execute()
            .value

        try await writeStops(routeID: result.id, stops: stops)
        return result.id
    }

    // MARK: - Update

    func updateRoute(routeID: String, title: String, stops: [Stop], tags: [String], price: Double?, thumbnailURL: URL?) async throws {
        guard let uid = currentUID else { throw URLError(.userAuthenticationRequired) }

        let totalMinutes = stops.reduce(0) { $0 + max(0, $1.timeSpent) }

        let row = RouteInsert(
            authorUid: uid,
            title: title,
            tags: tags,
            price: price,
            thumbnailUrl: thumbnailURL?.absoluteString,
            stopsCount: stops.count,
            duration: totalMinutes,
            isFree: price == nil || (price ?? 0) == 0,
            rating: 0,
            reviewCount: 0
        )

        try await supabase.from("routes").update(row).eq("id", value: routeID).execute()
        try await replaceStops(routeID: routeID, stops: stops)
    }

    // MARK: - Fetch (for Edit screen)

    func fetchRoute(routeID: String) async throws -> (title: String, stops: [Stop]) {
        let route: TourRoute = try await supabase
            .from("routes")
            .select()
            .eq("id", value: routeID)
            .single()
            .execute()
            .value

        let stops = try await SupabaseService.shared.fetchStops(for: routeID)
        return (route.title, stops)
    }

    // MARK: - Helpers

    private func writeStops(routeID: String, stops: [Stop]) async throws {
        let rows = stops.map { s in
            RouteStopInsert(
                routeId: routeID,
                placeId: nil,
                orderIndex: s.orderIndex,
                notes: s.notes,
                photoUrl: s.photoURL?.absoluteString,
                timeSpent: s.timeSpent
            )
        }
        try await supabase.from("route_stops").insert(rows).execute()
    }

    private func replaceStops(routeID: String, stops: [Stop]) async throws {
        try await supabase.from("route_stops").delete().eq("route_id", value: routeID).execute()
        try await writeStops(routeID: routeID, stops: stops)
    }
}
