import Foundation
import FirebaseFirestore

struct UserReview: Identifiable {
    var id: String              // review document ID
    let routeID: String
    let routeTitle: String      // convenience, fetched separately
    var rating: Int
    var text: String
    var createdAt: Date
}
