import CoreLocation
import Foundation

/// A place with everything the catalogue knows about it.
/// `Place` (in MapModels) stays the lightweight version used to draw map pins;
/// this one backs the browsable feed and the detail screen.
struct PlaceDetails: Identifiable, Equatable {
    let id: Int
    let name: String
    let category: PlaceCategory
    let address: String?
    let lat: Double?
    let lng: Double?
    let rating: Double
    let reviewCount: Int
    let priceRange: String?
    let tags: [String]
    let photoURL: URL?
    /// A quote pulled from public reviews during import.
    let description: String?
    /// Tropka's own take on the place — the thing that makes this more than a listing.
    let notes: String?
    let link: URL?
    let openingHoursRaw: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var isOpenNow: Bool? {
        OpeningHoursParser.isOpenNow(jsonString: openingHoursRaw)
    }

    var todayHours: String? {
        OpeningHoursParser.todayHours(jsonString: openingHoursRaw)
    }

    var week: [(day: String, hours: String, isToday: Bool)] {
        OpeningHoursParser.week(jsonString: openingHoursRaw)
    }

    static func == (lhs: PlaceDetails, rhs: PlaceDetails) -> Bool { lhs.id == rhs.id }
}

// MARK: - Sorting

enum PlaceSort: String, CaseIterable, Identifiable {
    case rating
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rating: return "Top rated"
        case .name:   return "A–Z"
        }
    }

    var icon: String {
        switch self {
        case .rating: return "star"
        case .name:   return "textformat.abc"
        }
    }

    var column: String {
        switch self {
        case .rating: return "rating_score"
        case .name:   return "name"
        }
    }

    var ascending: Bool { self == .name }
}
