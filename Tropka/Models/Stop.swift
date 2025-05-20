import Foundation
import FirebaseFirestore

// MARK: - Stop model (document in /routes/{routeId}/stops)

struct Stop: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinates: GeoPoint
    let orderIndex: Int
    let timeSpent: Int      // minutes
    let photoURL: URL?
    let notes: String?
}
