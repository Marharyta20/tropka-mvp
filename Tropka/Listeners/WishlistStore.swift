import Foundation
import Combine

// MARK: - WishlistStore
// Route-level wishlist is backed by the same saved_routes table.
// This store mirrors SavedRoutesStore so the heart button reflects
// the same state as the save button.

@MainActor
final class WishlistStore: ObservableObject {
    static let shared = WishlistStore()

    @Published private(set) var wishIDs: Set<String> = []

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = SavedRoutesStore.shared.$savedIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in self?.wishIDs = ids }
    }
}
