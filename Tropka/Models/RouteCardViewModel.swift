import Combine
import SwiftUI

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    let route: TourRoute
    private let saveSvc = SavedRoutesService()
    private var cancellable: AnyCancellable?

    init(route: TourRoute) {
        self.route = route

        cancellable = SavedRoutesStore.shared.$savedIDs
            .map { $0.contains(route.id) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSaved, on: self)
    }

    func save() async {
        guard !isSaved else { return }
        await toggle()
    }

    /// Flips the saved state and returns the state it ended up in, so the caller
    /// can report the right thing to the user even if the request failed.
    /// The UI updates first and rolls back on error — waiting for the network
    /// makes the bookmark feel broken.
    @discardableResult
    func toggle() async -> Bool {
        let wasSaved = isSaved
        isSaved = !wasSaved
        do {
            if wasSaved {
                try await saveSvc.remove(routeID: route.id)
            } else {
                try await saveSvc.save(routeID: route.id)
            }
        } catch {
            isSaved = wasSaved
        }
        return isSaved
    }
}
