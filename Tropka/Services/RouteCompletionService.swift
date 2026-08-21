import Foundation

// MARK: - RouteCompletionService (table: public.route_completions)

/// "I walked this route."
///
/// Bookmarking says *I might*; this says *I did*. It is the only signal the app
/// has that a route was actually used, which makes it the honest moment to ask
/// for a review — the review control used to be gated on the bookmark, so
/// somebody who walked a route without saving it could not review it at all.
///
/// A completion is private to the walker. The public number lives on
/// `routes.completed_count`, kept by a trigger, so showing "walked by 12" needs
/// no access to who those twelve people are.
struct RouteCompletionService {

    private var currentUID: String? { supabase.auth.currentUser?.id.uuidString }

    struct CompletionInsert: Encodable {
        let userId: String
        let routeId: String
        enum CodingKeys: String, CodingKey {
            case userId  = "user_id"
            case routeId = "route_id"
        }
    }

    // MARK: - Mark

    func markWalked(routeID: String) async throws {
        guard let uid = currentUID else { throw URLError(.userAuthenticationRequired) }
        // `ignoreDuplicates` rather than a plain upsert: the unique (user_id,
        // route_id) pair means one row per person per route, and walking the same
        // route twice must not look like two people walking it once.
        try await supabase
            .from("route_completions")
            .upsert(CompletionInsert(userId: uid, routeId: routeID),
                    onConflict: "user_id,route_id",
                    ignoreDuplicates: true)
            .execute()
    }

    // MARK: - Unmark

    func unmarkWalked(routeID: String) async throws {
        guard let uid = currentUID else { return }
        try await supabase
            .from("route_completions")
            .delete()
            .eq("user_id", value: uid)
            .eq("route_id", value: routeID)
            .execute()
    }

    // MARK: - Check

    func isWalked(routeID: String) async throws -> Bool {
        guard let uid = currentUID else { return false }
        struct IDRow: Decodable { let id: String }

        let rows: [IDRow] = try await supabase
            .from("route_completions")
            .select("id")
            .eq("user_id", value: uid)
            .eq("route_id", value: routeID)
            .limit(1)
            .execute()
            .value

        return !rows.isEmpty
    }

    /// Every route the signed-in user has finished, newest first. Powers the
    /// count on the profile.
    func walkedRouteIDs() async throws -> [String] {
        guard let uid = currentUID else { return [] }
        struct Row: Decodable {
            let routeId: String
            enum CodingKeys: String, CodingKey { case routeId = "route_id" }
        }

        let rows: [Row] = try await supabase
            .from("route_completions")
            .select("route_id")
            .eq("user_id", value: uid)
            .order("completed_at", ascending: false)
            .execute()
            .value

        return rows.map(\.routeId)
    }

    /// The routes themselves, newest walk first, for the profile's Walked tab.
    ///
    /// `routes` is optional on purpose: if an author flips a route to private,
    /// row level security stops returning it and the embed comes back null.
    /// Without this the whole list would fail to decode.
    func walkedRoutes() async throws -> [TourRoute] {
        guard let uid = currentUID else { return [] }
        struct CompletionRow: Decodable {
            let completedAt: Date?
            let routes: TourRoute?
            enum CodingKeys: String, CodingKey {
                case completedAt = "completed_at"
                case routes
            }
        }

        let rows: [CompletionRow] = try await supabase
            .from("route_completions")
            .select("completed_at, routes(*, users(full_name, username, photo_url))")
            .eq("user_id", value: uid)
            .order("completed_at", ascending: false)
            .execute()
            .value

        return rows.compactMap(\.routes)
    }
}
