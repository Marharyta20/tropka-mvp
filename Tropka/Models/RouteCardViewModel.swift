import SwiftUI

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    let route: TourRoute
    private let svc = SavedRoutesService()

    init(route: TourRoute) {
        self.route = route
        Task { isSaved = await svc.isSaved(routeID: route.id) }
    }

    func save() async {
        guard !isSaved else { return }
        isSaved = true                              // optimistic
        try? await svc.save(routeID: route.id)      // ignore error for now
    }
}
