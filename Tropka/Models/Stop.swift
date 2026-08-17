import Foundation
import CoreLocation

// MARK: - Stop model
// Assembled from a JOIN of route_stops + places in Supabase.

struct Stop: Identifiable, Equatable {
    let id: String
    /// public.places.id — route_stops.place_id is NOT NULL, so every stop is a
    /// real curated place rather than an arbitrary coordinate.
    let placeID: Int
    let name: String
    let lat: Double
    let lng: Double
    let orderIndex: Int
    let timeSpent: Int
    let photoURL: URL?
    let notes: String?

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
