import Foundation

// MARK: - SupabaseService
// Read access to routes and stops.

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    /// `users(...)` resolves through the routes.author_uid foreign key and gives
    /// us the author's display name in the same round trip.
    private static let routeColumns = "*, users(full_name, username, photo_url)"

    // MARK: - Routes

    /// Explore feed. The status filter is a UI nicety — row level security already
    /// hides other people's drafts and private routes, but without it the author
    /// would see their own unpublished ones mixed into the public feed.
    func fetchRoutes() async throws -> [TourRoute] {
        try await supabase
            .from("routes")
            .select(Self.routeColumns)
            .eq("status", value: RouteStatus.public.rawValue)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    /// Routes written by one user, every status — powers the "Created" tab.
    func fetchRoutes(authoredBy uid: String) async throws -> [TourRoute] {
        try await supabase
            .from("routes")
            .select(Self.routeColumns)
            .eq("author_uid", value: uid)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Single route, used to refresh a detail screen after an edit.
    func fetchRoute(id: String) async throws -> TourRoute {
        try await supabase
            .from("routes")
            .select(Self.routeColumns)
            .eq("id", value: id)
            .single()
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
                let lat: Double?
                let lng: Double?
                let photoUrl: String?
                let categoryId: Int?

                enum CodingKeys: String, CodingKey {
                    case name, lat, lng
                    case photoUrl = "photo_url"
                    case categoryId = "category_id"
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
            .select("id, place_id, order_index, notes, photo_url, time_spent, places(name, lat, lng, photo_url, category_id)")
            .eq("route_id", value: routeID)
            .order("order_index")
            .execute()
            .value

        return rows.map { row in
            Stop(
                id: row.id,
                placeID: row.placeId,
                name: row.places.name,
                category: row.places.categoryId.flatMap(PlaceCategory.init(rawValue:)) ?? .other,
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
