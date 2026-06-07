import Foundation

// MARK: - Review model (table: public.reviews)
// DB columns: id, route_id, user_id, rating, comment, created_at
// routeTitle is fetched via join (routes.title) and not stored in the DB.

struct UserReview: Identifiable {
    var id: String              // uuid
    let routeID: String
    let userID: String
    var routeTitle: String      // from routes(title) join — not a DB column
    var rating: Int             // 1-5
    var text: String            // maps to DB column "comment"
    var createdAt: Date
}
