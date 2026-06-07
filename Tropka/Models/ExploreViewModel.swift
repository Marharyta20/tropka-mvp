import SwiftUI
import Combine

@MainActor
class ExploreViewModel: ObservableObject {
    @Published var routes: [TourRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private var allRoutes: [TourRoute] = []

    init() { loadRoutes() }

    func loadRoutes() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await SupabaseService.shared.fetchRoutes()
                allRoutes = fetched
                routes    = fetched
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func filterRoutes() {
        if searchText.isEmpty {
            routes = allRoutes
        } else {
            routes = allRoutes.filter { route in
                route.title.localizedCaseInsensitiveContains(searchText) ||
                route.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}
