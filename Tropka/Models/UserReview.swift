struct UserReview: Identifiable {
    let id: String              // review document ID
    let routeID: String
    let routeTitle: String      // convenience, fetched separately
    var rating: Int
    var text: String
    let createdAt: Date
}
