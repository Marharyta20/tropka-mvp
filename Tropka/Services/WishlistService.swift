import Foundation

// MARK: - WishlistService
// Note: Supabase `wishlist` table stores place_id (places), not route_id.
// Route-level "wishlist" (heart button) is mapped to saved_routes in this app
// so both the Save and Heart buttons share the same backing table.

struct WishlistService {
    private let saveService = SavedRoutesService()

    func set(_ wished: Bool, routeID: String) async throws {
        if wished {
            try await saveService.save(routeID: routeID)
        } else {
            try await saveService.remove(routeID: routeID)
        }
    }

    func isWished(_ routeID: String) async -> Bool {
        await saveService.isSaved(routeID: routeID)
    }
}
