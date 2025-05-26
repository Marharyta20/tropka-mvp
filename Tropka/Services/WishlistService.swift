// WishlistService.swift
import FirebaseAuth
import FirebaseFirestore

struct WishlistService {
    private let db   = Firestore.firestore()
    private let auth = Auth.auth()

    func set(_ wished: Bool, routeID: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw URLError(.userAuthenticationRequired) }
        let ref = db.collection("users").document(uid)
            .collection("wishlist").document(routeID)

        if wished {
            try await ref.setData(["savedAt": Timestamp(date: Date())])
        } else {
            try await ref.delete()
        }
    }

    func isWished(_ routeID: String) async -> Bool {
        guard let uid = auth.currentUser?.uid else { return false }
        let snap = try? await db.collection("users").document(uid)
            .collection("wishlist").document(routeID).getDocument()
        return snap?.exists ?? false
    }
}
