import Combine
import CoreLocation
import Foundation

/// View-model providing places for the map and filtering logic.
final class MapViewModel: ObservableObject {
    @Published var places: [Place] = []
    @Published var searchQuery = ""
    @Published var selectedCategories = Set(PlaceCategory.allCases)
    @Published private var debouncedQuery = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedQuery)
    }

    var filteredPlaces: [Place] {
        places.filter { place in
            let matchesSearch = debouncedQuery.isEmpty ||
                place.name.localizedCaseInsensitiveContains(debouncedQuery) ||
                place.tags.contains { $0.localizedCaseInsensitiveContains(debouncedQuery) }
            let matchesCategory = selectedCategories.contains(place.category)
            return matchesSearch && matchesCategory
        }
    }

    // MARK: - Load from Supabase

    func loadPlaces() {
        Task {
            do {
                let loaded = try await fetchPlaces()
                await MainActor.run { self.places = loaded }
            } catch {
                print("❌ MapViewModel: failed to load places:", error)
            }
        }
    }

    private func fetchPlaces() async throws -> [Place] {
        struct PlaceRow: Decodable {
            let id: Int
            let name: String
            let lat: Double?
            let lng: Double?
            let ratingScore: Double?
            let ratingReviews: Int?
            let tags: [String]?
            let photoUrl: String?
            let categoryId: Int?

            enum CodingKeys: String, CodingKey {
                case id, name, lat, lng, tags
                case ratingScore   = "rating_score"
                case ratingReviews = "rating_reviews"
                case photoUrl      = "photo_url"
                case categoryId    = "category_id"
            }
        }

        let rows: [PlaceRow] = try await supabase
            .from("places")
            .select("id, name, lat, lng, rating_score, rating_reviews, tags, photo_url, category_id")
            .limit(300)
            .execute()
            .value

        return rows.compactMap { row in
            guard let lat = row.lat, let lng = row.lng else { return nil }
            return Place(
                id: String(row.id),
                name: row.name,
                category: placeCategory(for: row.categoryId),
                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                rating: row.ratingScore ?? 0,
                reviewCount: row.ratingReviews ?? 0,
                isOpenNow: true,
                tags: row.tags ?? [],
                photoURL: row.photoUrl.flatMap(URL.init)
            )
        }
    }

    // PlaceCategory's raw value is defined to match categories.id 1:1,
    // so no manual lookup table is needed — unknown/missing IDs fall back to .other.
    private func placeCategory(for id: Int?) -> PlaceCategory {
        guard let id else { return .other }
        return PlaceCategory(rawValue: id) ?? .other
    }
}
