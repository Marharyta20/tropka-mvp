import Foundation
import FirebaseFirestore

// MARK: - Stop model (document in /routes/{routeId}/stops)

struct Stop: Identifiable {
    let id:         String
    let name:       String
    let coordinate: GeoPoint
    let order:      Int            // renamed
    let timeSpent:  Int            // minutes
    let photoURL:   URL?           // real URL
}

