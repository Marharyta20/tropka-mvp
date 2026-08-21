import Combine
import CoreLocation
import Foundation

/// Places for the map, and the filtering on top of them.
///
/// The map used to load 300 rows and call it a day — a fifth of the catalogue,
/// chosen at random by the database. It now loads every listed place; the pins are
/// clustered rather than capped. Only the columns a pin needs are fetched: opening
/// hours and tags are heavy and the place card loads them on demand.
@MainActor
final class MapViewModel: ObservableObject {
    @Published var places: [Place] = []
    /// Rendered by `MapScreenView`. A silent failure here left the user looking at
    /// an empty Warsaw with nothing to explain it.
    @Published private(set) var loadError: String?
    @Published var searchQuery = ""
    @Published var selectedCategories = Set(PlaceCategory.allCases)
    @Published private var debouncedQuery = ""

    private let pageSize = 1000

    init() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedQuery)
    }

    // MARK: - Filtering

    var filteredPlaces: [Place] {
        places.filter { place in
            let matchesSearch = debouncedQuery.isEmpty ||
                place.name.localizedCaseInsensitiveContains(debouncedQuery)
            return matchesSearch && selectedCategories.contains(place.category)
        }
    }

    var showsEverything: Bool {
        selectedCategories.count == PlaceCategory.allCases.count
    }

    /// Categories that actually exist in the loaded data, most common first — a chip
    /// for a category with no places is a dead end.
    var availableCategories: [PlaceCategory] {
        let byFrequency = Dictionary(grouping: places, by: \.category)
            .sorted { $0.value.count > $1.value.count }
            .map(\.key)
        // The user's own categories come first, then the rest by how common they
        // are. Ordering only — no chip disappears.
        return UserPreferences.shared.ranked(byFrequency)
    }

    func isolated(_ category: PlaceCategory) -> Bool {
        selectedCategories == [category]
    }

    /// Tapping a chip shows that category alone; tapping it again brings everything
    /// back. Map filters are a "show me only cafes" gesture, not a checklist.
    func toggleIsolated(_ category: PlaceCategory) {
        selectedCategories = isolated(category) ? Set(PlaceCategory.allCases) : [category]
    }

    // MARK: - Loading

    func loadPlaces(force: Bool = false) {
        if force { places = [] }
        guard places.isEmpty else { return }
        // The catalogue arrives in pages, so the initial load runs for a while.
        // Without holding on to the task, leaving and re-entering the Map tab
        // during it started a second full pagination loop over the same rows.
        guard loadTask == nil else { return }

        loadError = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                self.places = try await self.fetchAllPlaces()
            } catch {
                self.loadError = error.localizedDescription
            }
        }
    }

    private var loadTask: Task<Void, Never>?

    private struct PlaceRow: Decodable {
        let id: Int
        let name: String
        let lat: Double?
        let lng: Double?
        let ratingScore: Double?
        let ratingReviews: Int?
        let photoUrl: String?
        let categoryId: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, lat, lng
            case ratingScore   = "rating_score"
            case ratingReviews = "rating_reviews"
            case photoUrl      = "photo_url"
            case categoryId    = "category_id"
        }
    }

    /// PostgREST caps a response at 1000 rows, so the catalogue arrives in pages.
    private func fetchAllPlaces() async throws -> [Place] {
        var collected: [Place] = []
        var offset = 0

        while true {
            let rows: [PlaceRow] = try await supabase
                .from("places")
                .select("id, name, lat, lng, rating_score, rating_reviews, photo_url, category_id")
                .eq("is_listed", value: true)
                .order("id")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            collected.append(contentsOf: rows.compactMap(Self.map))
            if rows.count < pageSize { break }
            offset += rows.count
        }

        return collected
    }

    // PlaceCategory's raw value matches categories.id 1:1, so no lookup table is
    // needed — unknown or missing ids fall back to .other.
    private static func map(_ row: PlaceRow) -> Place? {
        guard let lat = row.lat, let lng = row.lng else { return nil }
        return Place(
            id: String(row.id),
            name: row.name,
            category: row.categoryId.flatMap(PlaceCategory.init(rawValue:)) ?? .other,
            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            rating: row.ratingScore ?? 0,
            reviewCount: row.ratingReviews ?? 0,
            isOpenNow: nil,
            tags: [],
            photoURL: row.photoUrl.flatMap(URL.init)
        )
    }
}
