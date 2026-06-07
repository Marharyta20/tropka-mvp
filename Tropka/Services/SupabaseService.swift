import Foundation

// MARK: - SupabaseService
// Replaces FirestoreService. Provides read access to routes and stops.

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    // MARK: - Routes

    func fetchRoutes() async throws -> [TourRoute] {
        try await supabase
            .from("routes")
            .select()
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    // MARK: - Stops (route_stops JOIN places)

    func fetchStops(for routeID: String) async throws -> [Stop] {
        struct StopRow: Decodable {
            let id: String
            let orderIndex: Int
            let notes: String?
            let photoUrl: String?
            let timeSpent: Int?
            let places: PlaceInfo

            struct PlaceInfo: Decodable {
                let name: String
                let lat: Double
                let lng: Double
            }

            enum CodingKeys: String, CodingKey {
                case id
                case orderIndex = "order_index"
                case notes
                case photoUrl = "photo_url"
                case timeSpent = "time_spent"
                case places
            }
        }

        let rows: [StopRow] = try await supabase
            .from("route_stops")
            .select("id, order_index, notes, photo_url, time_spent, places(name, lat, lng)")
            .eq("route_id", value: routeID)
            .order("order_index")
            .execute()
            .value

        return rows.map { row in
            Stop(
                id: row.id,
                name: row.places.name,
                lat: row.places.lat,
                lng: row.places.lng,
                orderIndex: row.orderIndex,
                timeSpent: row.timeSpent ?? 0,
                photoURL: row.photoUrl.flatMap(URL.init),
                notes: row.notes
            )
        }
    }
}

// Backward-compat alias so existing call-sites compile without changes.
typealias FirestoreService = SupabaseService
