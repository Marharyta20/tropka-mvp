import FirebaseAuth
import FirebaseFirestore

struct ReviewService {
    private let db   = Firestore.firestore()
    private let auth = Auth.auth()

    func fetchMyReviews() async throws -> [UserReview] {
        guard let uid = auth.currentUser?.uid else { return [] }

        // ❶ query all reviews by me (collection group)
        let qs = try await db.collectionGroup("reviews")
            .whereField("authorUID", isEqualTo: uid)
            .getDocuments()

        var result: [UserReview] = []
        for doc in qs.documents {
            let data = doc.data()

            // parent route ID is 3rd path component: routes/{id}/reviews/{doc}
            let routeID = doc.reference.path.components(separatedBy: "/")[1]

            // minimal route title (2nd query)
            let routeSnap = try? await db.collection("routes").document(routeID).getDocument()
            let title = routeSnap??.data()?["title"] as? String ?? "Untitled"

            result.append(
                UserReview(id: doc.documentID,
                           routeID: routeID,
                           routeTitle: title,
                           rating: data["rating"] as? Int ?? 0,
                           text: data["text"] as? String ?? "",
                           createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now)
            )
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    func update(review: UserReview) async throws {
        try await db.collection("routes").document(review.routeID)
            .collection("reviews").document(review.id)
            .updateData([
                "rating": review.rating,
                "text"  : review.text
            ])
    }

    func delete(review: UserReview) async throws {
        try await db.collection("routes").document(review.routeID)
            .collection("reviews").document(review.id)
            .delete()
    }
}
