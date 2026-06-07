import Foundation

// MARK: - ReviewService (table: public.reviews)
// DB columns: id, route_id, user_id, rating, comment, created_at
// Note: DB uses "comment"; app model uses "text" — mapped in this service.

struct ReviewService {

    private func currentUID() throws -> String {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            throw URLError(.userAuthenticationRequired)
        }
        return uid
    }

    // MARK: - Internal row types

    private struct ReviewRow: Decodable {
        let id: String
        let routeId: String
        let userId: String
        let rating: Int
        let comment: String?
        let createdAt: Date
        let routes: RouteTitle?

        struct RouteTitle: Decodable { let title: String }

        enum CodingKeys: String, CodingKey {
            case id
            case routeId = "route_id"
            case userId = "user_id"
            case rating, comment
            case createdAt = "created_at"
            case routes
        }

        func toUserReview() -> UserReview {
            UserReview(
                id: id,
                routeID: routeId,
                userID: userId,
                routeTitle: routes?.title ?? "Untitled",
                rating: rating,
                text: comment ?? "",
                createdAt: createdAt
            )
        }
    }

    private struct ReviewUpsert: Encodable {
        let id: String
        let routeId: String
        let userId: String
        let rating: Int
        let comment: String
        enum CodingKeys: String, CodingKey {
            case id
            case routeId = "route_id"
            case userId = "user_id"
            case rating, comment
        }
    }

    // MARK: - Fetch all my reviews

    func fetchMyReviews() async throws -> [UserReview] {
        let uid = try currentUID()
        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select("id, route_id, user_id, rating, comment, created_at, routes(title)")
            .eq("user_id", value: uid)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toUserReview() }
    }

    // MARK: - Fetch single review for a route

    func fetchMyReview(routeID: String) async throws -> UserReview? {
        let uid = try currentUID()
        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select("id, route_id, user_id, rating, comment, created_at, routes(title)")
            .eq("user_id", value: uid)
            .eq("route_id", value: routeID)
            .limit(1)
            .execute()
            .value
        return rows.first?.toUserReview()
    }

    // MARK: - Upsert (create or update)

    @discardableResult
    func upsert(review: UserReview) async throws -> UserReview {
        let uid = try currentUID()
        let reviewID = review.id.isEmpty ? UUID().uuidString : review.id
        let row = ReviewUpsert(
            id: reviewID,
            routeId: review.routeID,
            userId: uid,
            rating: review.rating,
            comment: review.text
        )
        try await supabase.from("reviews").upsert(row).execute()
        var saved = review
        saved = UserReview(
            id: reviewID,
            routeID: review.routeID,
            userID: uid,
            routeTitle: review.routeTitle,
            rating: review.rating,
            text: review.text,
            createdAt: review.createdAt
        )
        return saved
    }

    func create(review: UserReview) async throws { try await upsert(review: review) }
    func update(review: UserReview) async throws { try await upsert(review: review) }

    // MARK: - Delete

    func delete(review: UserReview) async throws {
        try await supabase
            .from("reviews")
            .delete()
            .eq("id", value: review.id)
            .execute()
    }
}
