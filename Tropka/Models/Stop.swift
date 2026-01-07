import Foundation
import FirebaseFirestore
import CoreLocation

struct Stop: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinates: GeoPoint 
    let orderIndex: Int
    let timeSpent: Int
    let photoURL: URL?
    let notes: String?
    
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
}
