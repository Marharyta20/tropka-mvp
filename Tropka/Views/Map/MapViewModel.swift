import Combine
import CoreLocation
import FirebaseFirestore
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

    func loadPlaces() {
        // TODO: Load from Firestore. Using mock data for now.
        places = [
            Place(
                id: "1",
                name: "Forum Café",
                category: .cafe,
                coordinates: CLLocationCoordinate2D(latitude: 52.231, longitude: 21.01),
                rating: 4.8,
                reviewCount: 156,
                isOpenNow: true,
                tags: ["coffee", "cozy", "wifi"],
                photoURL: nil
            ),
            Place(
                id: "2",
                name: "Old Town Market",
                category: .shopping,
                coordinates: CLLocationCoordinate2D(latitude: 52.235, longitude: 21.02),
                rating: 4.5,
                reviewCount: 89,
                isOpenNow: true,
                tags: ["local", "souvenirs", "historic"],
                photoURL: nil
            )
        ]
    }
}
