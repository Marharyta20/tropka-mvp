import SwiftUI
import Combine

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    let route: TourRoute
    private let saveSvc = SavedRoutesService()
    private var cancellable: AnyCancellable?
    
    @Published var isWished = false
    private let wishSvc = WishlistService()
    private var wishCancellable: AnyCancellable?
    
    init(route: TourRoute) {
        self.route = route
        
        cancellable = SavedRoutesStore.shared.$savedIDs
            .map { $0.contains(route.id) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSaved, on: self)
        
        wishCancellable = WishlistStore.shared.$wishIDs
            .map { $0.contains(route.id) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isWished, on: self)
    }
    
    func save() async {
        guard !isSaved else { return }
        isSaved = true
        try? await saveSvc.save(routeID: route.id)
    }
    
    func toggleWishlist() {
        Task {
            let newVal = !isWished
            isWished = newVal                        // optimistic UI
            do {
                try await wishSvc.set(newVal, routeID: route.id)
            } catch {
                print("❌ Wishlist write failed:", error)
                await MainActor.run { self.isWished = !newVal }
            }
        }
    }
}
