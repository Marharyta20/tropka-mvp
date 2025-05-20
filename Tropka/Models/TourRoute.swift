import Foundation
import FirebaseFirestore   // for GeoPoint

// MARK: - Route model (document in /routes)

struct TourRoute: Identifiable {
    /// Firestore document ID (parsed manually)
    let id: String

    // Core fields
    let title: String
    let authorUID: String

    // Ratings & meta
    let rating: Double
    let reviewCount: Int
    let duration: Double          // hours

    // Tags & pricing
    let tags: [String]
    let price: Double?            // nil → free

    // Media
    let thumbnailURL: URL?

    // Convenience
    var isFree: Bool { price == nil }
    
    let stopsCount: Int
}
