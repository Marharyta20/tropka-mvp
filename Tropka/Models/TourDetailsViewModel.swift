import Foundation
import FirebaseFirestore              // Firestore + GeoPoint
import Combine

final class TourDetailsViewModel: ObservableObject {

    @Published var stops: [Stop] = []
    @Published var isLoading = false
    @Published var errorMsg: String?

    /// Loads all stops for a given route (sub-collection `/stops`)
    func loadStops(routeID: String) {
        isLoading = true; errorMsg = nil
        FirestoreService.shared.fetchStops(for: routeID) { [weak self] res in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch res {
                case .success(let s): self?.stops = s
                case .failure(let e): self?.errorMsg = e.localizedDescription
                }
            }
        }
    }
}
