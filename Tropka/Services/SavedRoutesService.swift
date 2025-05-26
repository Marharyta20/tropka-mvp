import FirebaseAuth
import FirebaseFirestore
import Foundation

struct SavedRoutesService {
    private let db   = Firestore.firestore()
    private let auth = Auth.auth()

    func save(routeID: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw URLError(.userAuthenticationRequired) }
        try await db.collection("users")
            .document(uid)
            .collection("savedRoutes")
            .document(routeID)
            .setData([
                "savedAt"    : Timestamp(date: Date()),
                "isPurchased": false
            ])
    }

    func isSaved(routeID: String) async -> Bool {
        guard let uid = auth.currentUser?.uid else { return false }
        let doc = try? await db.collection("users")
            .document(uid)
            .collection("savedRoutes")
            .document(routeID)
            .getDocument()
        return doc?.exists ?? false
    }
}
