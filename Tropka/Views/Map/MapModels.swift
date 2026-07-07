import SwiftUI
import CoreLocation

extension Notification.Name {
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
}

/// Categories of places shown on the map.
/// Raw value matches `public.categories.id` in Supabase 1:1 so decoding
/// a place's `category_id` never needs a hand-maintained lookup table.
enum PlaceCategory: Int, CaseIterable {
    case other = 0
    case restaurant = 1
    case cafe = 2
    case coffeeShop = 3
    case bar = 4
    case bakery = 5
    case museum = 6
    case park = 7
    case artGallery = 8
    case theater = 9
    case landmark = 10
    case shop = 11
    case viewpoint = 12
    case market = 13
    case concertVenue = 14
    case nightclub = 15
    case hotel = 16

    /// Human-readable label, mirrors `categories.name` in Supabase.
    var displayName: String {
        switch self {
        case .other:        return "Other"
        case .restaurant:   return "Restaurant"
        case .cafe:         return "Cafe"
        case .coffeeShop:   return "Coffee Shop"
        case .bar:          return "Bar"
        case .bakery:       return "Bakery"
        case .museum:       return "Museum"
        case .park:         return "Park"
        case .artGallery:   return "Art Gallery"
        case .theater:      return "Theater"
        case .landmark:     return "Landmark"
        case .shop:         return "Shop"
        case .viewpoint:    return "Viewpoint"
        case .market:       return "Market"
        case .concertVenue: return "Concert Venue"
        case .nightclub:    return "Night Club"
        case .hotel:        return "Hotel"
        }
    }

    var color: UIColor {
        switch self {
        case .other:        return .systemGray
        case .restaurant:   return .systemRed
        case .cafe:         return .systemBrown
        case .coffeeShop:   return .systemOrange
        case .bar:          return .systemPink
        case .bakery:       return .systemYellow
        case .museum:       return .systemPurple
        case .park:         return .systemGreen
        case .artGallery:   return .systemTeal
        case .theater:      return .systemIndigo
        case .landmark:     return .systemMint
        case .shop:         return .systemBlue
        case .viewpoint:    return .systemCyan
        case .market:       return .systemOrange
        case .concertVenue: return .systemIndigo
        case .nightclub:    return .systemPurple
        case .hotel:        return UIColor(red: 0x3F/255, green: 0x51/255, blue: 0xB5/255, alpha: 1) // matches categories.color "#3F51B5"
        }
    }

    var icon: String {
        switch self {
        case .other:        return "mappin.circle"
        case .restaurant:   return "fork.knife"
        case .cafe:         return "cup.and.saucer"
        case .coffeeShop:   return "cup.and.saucer.fill"
        case .bar:          return "wineglass"
        case .bakery:       return "birthday.cake"
        case .museum:       return "building.columns"
        case .park:         return "leaf"
        case .artGallery:   return "paintpalette"
        case .theater:      return "theatermasks.fill"
        case .landmark:     return "building.2"
        case .shop:         return "bag"
        case .viewpoint:    return "binoculars.fill"
        case .market:       return "cart.fill"
        case .concertVenue: return "music.note"
        case .nightclub:    return "moon.stars.fill"
        case .hotel:        return "bed.double.fill"
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
