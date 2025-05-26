import SwiftUI
import Combine

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    let route: TourRoute
    private let svc = SavedRoutesService()
    private var cancellable: AnyCancellable?

    init(route: TourRoute) {
        self.route = route
        cancellable = SavedRoutesStore.shared.$savedIDs
            .map { $0.contains(route.id) }
            .assign(to: \.isSaved, on: self)
    }

    func save() async {
        guard !isSaved else { return }
        isSaved = true                              // optimistic
        try? await svc.save(routeID: route.id)      // ignore error for now
    }
}
