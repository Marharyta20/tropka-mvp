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
    /// Author and licence of the photo, when it comes from a source that requires
    /// credit (Wikimedia). nil for photos that need none.
    let photoAttribution: String?
    /// What the place *is*, in one or two sentences. Wikipedia where there is an
    /// article, Google's editorial copy otherwise.
    let summary: String?
    /// Required by CC BY-SA when the summary came from Wikipedia: names the
    /// source article.
    let summaryAttribution: String?
    /// The article itself. The licence asks for the source to be reachable, not
    /// just named — but a raw encyclopaedia URL printed under the text is ugly
    /// and, percent-escaped and truncated, unreadable. It goes behind the name.
    let summaryURL: URL?
    /// What somebody *said* about the place. Only ever a quote now — the
    /// descriptions that used to share this column moved to `summary`, because
    /// showing them in italics under "What people say" put an encyclopaedia's
    /// words in a visitor's mouth.
    let description: String?
    /// Atmosphere, amenities and who a place suits, from `google_maps_attributes`.
    let highlights: [PlaceHighlight]
    /// Tropka's own take on the place — the thing that makes this more than a listing.
    let notes: String?
    let link: URL?
    /// The place's own Google Maps listing, straight from `source_url`. It is what
    /// makes the imported rating honest: the number is Google's, and this is where
    /// the reviews behind it can actually be read.
    let sourceURL: URL?
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
