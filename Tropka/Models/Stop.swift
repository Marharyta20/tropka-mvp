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
    /// Mirrors the place's category — used for the fallback thumbnail.
    let category: PlaceCategory
    /// Nullable in `places`, so nullable here. A stop the catalogue has no
    /// coordinates for still belongs in the list — it just cannot be drawn.
    /// Declaring these non-optional made one such row throw during decoding and
    /// take the entire route's stop list with it.
    let lat: Double?
    let lng: Double?
    let orderIndex: Int
    let timeSpent: Int
    let photoURL: URL?
    let notes: String?

    var location: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
