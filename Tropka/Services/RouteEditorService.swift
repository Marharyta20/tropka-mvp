import Foundation

// MARK: - RouteEditorService (Supabase)

/// Create / update / delete for routes the signed-in user authors.
///
/// Two things the database takes care of, so this service never writes them:
///   • `routes.duration` — recomputed by the route_stops_sync_route_duration trigger
///   • `routes.rating` / `review_count` — recomputed by reviews_sync_route_rating
/// Sending them from here would clobber real ratings on every edit.
struct RouteEditorService {

    private var currentUID: String? { supabase.auth.currentUser?.id.uuidString }

    // MARK: - Row types

    private struct RouteInsert: Encodable {
        let authorUid: String
        let title: String
        let tags: [String]
        let thumbnailUrl: String?
        let stopsCount: Int

        enum CodingKeys: String, CodingKey {
            case authorUid    = "author_uid"
            case title, tags
            case thumbnailUrl = "thumbnail_url"
            case stopsCount   = "stops_count"
        }
    }

    private struct RouteUpdate: Encodable {
        let title: String
        let tags: [String]
        let thumbnailUrl: String?
        let stopsCount: Int

        enum CodingKeys: String, CodingKey {
            case title, tags
            case thumbnailUrl = "thumbnail_url"
            case stopsCount   = "stops_count"
        }
    }

    private struct RouteStopInsert: Encodable {
        let routeId: String
        /// NOT NULL in the schema — a stop is always one of the curated places.
        let placeId: Int
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

    func createRoute(title: String,
                     tags: [String],
                     thumbnailURL: URL?,
                     stops: [DraftStop]) async throws -> String {
        guard let uid = currentUID else { throw URLError(.userAuthenticationRequired) }

        let row = RouteInsert(
            authorUid: uid,
            title: title,
            tags: tags,
            thumbnailUrl: thumbnailURL?.absoluteString,
            stopsCount: stops.count
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

    func updateRoute(routeID: String,
                     title: String,
                     tags: [String],
                     thumbnailURL: URL?,
                     stops: [DraftStop]) async throws {
        let row = RouteUpdate(
            title: title,
            tags: tags,
            thumbnailUrl: thumbnailURL?.absoluteString,
            stopsCount: stops.count
        )

        // Row-level security limits this to routes the caller authored.
        try await supabase
            .from("routes")
            .update(row)
            .eq("id", value: routeID)
            .execute()

        try await replaceStops(routeID: routeID, stops: stops)
    }

    // MARK: - Append a single stop

    /// Adds one place to the end of an existing route.
    /// Returns false when that place is already a stop, so the caller can say so
    /// instead of silently creating a duplicate.
    ///
    /// `stops_count` has no database trigger behind it (unlike duration and rating),
    /// so it is kept in sync here by hand.
    @discardableResult
    func appendStop(to routeID: String,
                    placeID: Int,
                    photoURL: URL?,
                    timeSpent: Int = 30) async throws -> Bool {

        struct ExistingStop: Decodable {
            let placeId: Int
            let orderIndex: Int
            enum CodingKeys: String, CodingKey {
                case placeId = "place_id"
                case orderIndex = "order_index"
            }
        }

        let existing: [ExistingStop] = try await supabase
            .from("route_stops")
            .select("place_id, order_index")
            .eq("route_id", value: routeID)
            .execute()
            .value

        guard !existing.contains(where: { $0.placeId == placeID }) else { return false }

        let row = RouteStopInsert(
            routeId: routeID,
            placeId: placeID,
            orderIndex: (existing.map(\.orderIndex).max() ?? 0) + 1,
            notes: nil,
            photoUrl: photoURL?.absoluteString,
            timeSpent: max(0, timeSpent)
        )
        try await supabase.from("route_stops").insert(row).execute()

        struct StopsCountUpdate: Encodable {
            let stopsCount: Int
            enum CodingKeys: String, CodingKey { case stopsCount = "stops_count" }
        }
        try await supabase
            .from("routes")
            .update(StopsCountUpdate(stopsCount: existing.count + 1))
            .eq("id", value: routeID)
            .execute()

        return true
    }

    // MARK: - Delete

    func deleteRoute(routeID: String) async throws {
        try await supabase.from("route_stops").delete().eq("route_id", value: routeID).execute()
        try await supabase.from("routes").delete().eq("id", value: routeID).execute()
    }

    // MARK: - Fetch (for the edit screen)

    func fetchForEditing(routeID: String) async throws
    -> (title: String, tags: [String], thumbnailURL: URL?, stops: [DraftStop]) {
        let route: TourRoute = try await supabase
            .from("routes")
            .select()
            .eq("id", value: routeID)
            .single()
            .execute()
            .value

        let saved = try await SupabaseService.shared.fetchStops(for: routeID)
        return (route.title, route.tags, route.thumbnailURL, saved.map(DraftStop.init(stop:)))
    }

    // MARK: - Helpers

    private func writeStops(routeID: String, stops: [DraftStop]) async throws {
        guard !stops.isEmpty else { return }

        // order_index is derived from array position, so reordering in the UI is
        // all the author has to do — no manual numbering.
        let rows = stops.enumerated().map { index, s in
            RouteStopInsert(
                routeId: routeID,
                placeId: s.placeID,
                orderIndex: index + 1,
                notes: s.notes.isEmpty ? nil : s.notes,
                photoUrl: s.photoURL?.absoluteString,
                timeSpent: max(0, s.timeSpent)
            )
        }
        try await supabase.from("route_stops").insert(rows).execute()
    }

    private func replaceStops(routeID: String, stops: [DraftStop]) async throws {
        try await supabase.from("route_stops").delete().eq("route_id", value: routeID).execute()
        try await writeStops(routeID: routeID, stops: stops)
    }
}
