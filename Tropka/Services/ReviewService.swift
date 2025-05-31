import FirebaseAuth
import FirebaseFirestore

struct ReviewService {
    // MARK: – private
       private let db   = Firestore.firestore()
       private let auth = Auth.auth()

       /// Firestore data-payload (one place → one format)
       private func payload(for r: UserReview) -> [String:Any] {
           [
               "authorUID" : auth.currentUser!.uid,
               "rating"    : r.rating,
               "text"      : r.text,
               "createdAt" : Timestamp(date: r.createdAt)
           ]
       }

    // ──────────────────────────────────────────────
    // MARK: Fetch

    /// All reviews written by the current user (profile tab)
    func fetchMyReviews() async throws -> [UserReview] {
        guard let uid = auth.currentUser?.uid else { return [] }

        let qs = try await db.collection("users")
                             .document(uid)
                             .collection("reviews")
                             .getDocuments()

        var arr: [UserReview] = []
        for doc in qs.documents {
            let d = doc.data()
            arr.append(
                UserReview(
                    id: doc.documentID,
                    routeID: doc.documentID,
                    routeTitle: d["routeTitle"] as? String ?? "Untitled",
                    rating: d["rating"] as? Int ?? 0,
                    text: d["text"] as? String ?? "",
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
                )
            )
        }
        return arr.sorted { $0.createdAt > $1.createdAt }
    }

    /// Single review by me for a particular route (details screen)
    func fetchMyReview(routeID: String) async throws -> UserReview? {
        guard let uid = auth.currentUser?.uid else { return nil }

        let snap = try await db.collection("users")
                               .document(uid)
                               .collection("reviews")
                               .document(routeID)
                               .getDocument()

        guard let data = snap.data() else { return nil }

        return UserReview(
            id: routeID,                       // docID == routeID
            routeID: routeID,
            routeTitle: data["routeTitle"] as? String ?? "Untitled",
            rating: data["rating"] as? Int ?? 0,
            text: data["text"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }

    // ──────────────────────────────────────────────
    // MARK: Create / Update / Delete

    func create(review: UserReview) async throws {
        let doc = db.collection("routes").document(review.routeID)
            .collection("reviews").document(review.id)

        try await doc.setData([
            "authorUID" : auth.currentUser?.uid ?? "",
            "rating"    : review.rating,
            "text"      : review.text,
            "createdAt" : Timestamp(date: review.createdAt)
        ])
    }

    func update(review: UserReview) async throws {
        try await db.collection("routes").document(review.routeID)
            .collection("reviews").document(review.id)
            .updateData([
                "rating": review.rating,
                "text"  : review.text
            ])
    }

    // ──────────────────────────────────────────────
    // MARK: Upsert 

    /// Creates **or** updates the review and returns the stored copy
    @discardableResult
    func upsert(review: UserReview) async throws -> UserReview {
        
        guard let uid = auth.currentUser?.uid else { return review }
        
        let routeDoc = db.collection("routes")
            .document(review.routeID)
            .collection("reviews")
            .document(uid)
        
        let userDoc = db.collection("users")
            .document(uid)
            .collection("reviews")
            .document(review.routeID)
        
        let baseData = payload(for: review)
        let data = baseData.merging(["routeTitle": review.routeTitle]) { _, new in new }
        
        try await routeDoc.setData(data, merge: true)
        try await userDoc.setData(data, merge: true)
        
        return review
    }
    
    // MARK: Delete
    func delete(review: UserReview) async throws {
        guard let uid = auth.currentUser?.uid else { return }

        try await db.collection("routes")
                    .document(review.routeID)
                    .collection("reviews")
                    .document(uid)
                    .delete()

        try await db.collection("users")
                    .document(uid)
                    .collection("reviews")
                    .document(review.routeID)
                    .delete()
    }

}
