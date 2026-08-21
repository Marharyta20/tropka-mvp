import Combine
import SwiftUI

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    /// Mirrors the shared store, so a route marked walked on its own screen shows
    /// the badge on every card without any of them refetching.
    @Published var isWalked = false
    let route: TourRoute
    private let saveSvc = SavedRoutesService()
    private var cancellable: AnyCancellable?
    private var walkedCancellable: AnyCancellable?

    init(route: TourRoute) {
        self.route = route

        cancellable = SavedRoutesStore.shared.$savedIDs
            .map { $0.contains(route.id) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSaved, on: self)

        walkedCancellable = WalkedRoutesStore.shared.$walkedIDs
            .map { $0.contains(route.id) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isWalked, on: self)
    }

    @discardableResult
    func save() async -> BookmarkOutcome {
        guard !isSaved else { return .saved }
        return await toggle()
    }

    /// Flips the saved state and reports what actually happened.
    ///
    /// It used to return the state it ended up in, which is the same value for
    /// "removed successfully" and "failed to save and rolled back" — so a save
    /// that never reached the server told the user "Removed from your routes"
    /// and logged `route_unsaved` to analytics. A failure is now its own case.
    ///
    /// The UI still updates first and rolls back on error: waiting for the
    /// network makes the bookmark feel broken.
    @discardableResult
    func toggle() async -> BookmarkOutcome {
        let wasSaved = isSaved
        isSaved = !wasSaved
        do {
            if wasSaved {
                try await saveSvc.remove(routeID: route.id)
            } else {
                try await saveSvc.save(routeID: route.id)
            }
            return wasSaved ? .removed : .saved
        } catch {
            isSaved = wasSaved
            return .failed(ErrorText.friendly(error.localizedDescription))
        }
    }
}

/// What a bookmark tap did, as opposed to what the button now looks like.
enum BookmarkOutcome: Equatable {
    case saved
    case removed
    case failed(String)
}
