import SwiftUI
import CoreLocation

extension Notification.Name {
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
}

/// Categories of places shown on the map.
enum PlaceCategory: String, CaseIterable {
    case restaurant, cafe, museum, park, shopping, nightlife, historical

    var color: UIColor {
        switch self {
        case .restaurant: return .systemRed
        case .cafe: return .systemBrown
        case .museum: return .systemPurple
        case .park: return .systemGreen
        case .shopping: return .systemBlue
        case .nightlife: return .systemIndigo
        case .historical: return .systemOrange
        }
    }

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer"
        case .museum: return "building.columns"
        case .park: return "leaf"
        case .shopping: return "bag"
        case .nightlife: return "moon.stars"
        case .historical: return "building.2"
        }
    }
}

/// Represents a place on the map.
struct Place: Identifiable {
    let id: String
    let name: String
    let category: PlaceCategory
    let coordinates: CLLocationCoordinate2D
    let rating: Double
    let reviewCount: Int
    let isOpenNow: Bool
    let tags: [String]
    let photoURL: URL?

    // UI data
    var distanceFromUser: Double?
    var relatedRoutes: [TourRoute] = []
}
