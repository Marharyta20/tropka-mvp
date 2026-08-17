import Foundation

// MARK: - SupabaseService
// Read access to routes and stops.

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    /// `users(...)` resolves through the routes.author_uid foreign key and gives
    /// us the author's display name in the same round trip.
    private static let routeColumns = "*, users(full_name, username)"

    // MARK: - Routes

    func fetchRoutes() async throws -> [TourRoute] {
        try await supabase
            .from("routes")
            .select(Self.routeColumns)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    /// Routes written by one user — powers the "Created" tab in the profile.
    func fetchRoutes(authoredBy uid: String) async throws -> [TourRoute] {
        try await supabase
            .from("routes")
            .select(Self.routeColumns)
            .eq("author_uid", value: uid)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Stops (route_stops JOIN places)

    func fetchStops(for routeID: String) async throws -> [Stop] {
        struct StopRow: Decodable {
            let id: String
            let placeId: Int
            let orderIndex: Int
            let notes: String?
            let photoUrl: String?
            let timeSpent: Int?
            let places: PlaceInfo

            struct PlaceInfo: Decodable {
                let name: String
                let lat: Double
                let lng: Double
                let photoUrl: String?

                enum CodingKeys: String, CodingKey {
                    case name, lat, lng
                    case photoUrl = "photo_url"
                }
            }

            enum CodingKeys: String, CodingKey {
                case id
                case placeId = "place_id"
                case orderIndex = "order_index"
                case notes
                case photoUrl = "photo_url"
                case timeSpent = "time_spent"
                case places
            }
        }

        let rows: [StopRow] = try await supabase
            .from("route_stops")
            .select("id, place_id, order_index, notes, photo_url, time_spent, places(name, lat, lng, photo_url)")
            .eq("route_id", value: routeID)
            .order("order_index")
            .execute()
            .value

        return rows.map { row in
            Stop(
                id: row.id,
                placeID: row.placeId,
                name: row.places.name,
                lat: row.places.lat,
                lng: row.places.lng,
                orderIndex: row.orderIndex,
                timeSpent: row.timeSpent ?? 0,
                // A stop may carry its own photo; fall back to the place's.
                photoURL: (row.photoUrl ?? row.places.photoUrl).flatMap(URL.init),
                notes: row.notes
            )
        }
    }
}
