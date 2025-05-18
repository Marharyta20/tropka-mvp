import Foundation
import Combine

final class RoutesViewModel: ObservableObject {
    @Published var routes: [Route] = []
    @Published var isLoading = false
    @Published var errorMsg: String?

    /// Простой пример загрузки – подставьте ваш Firestore-сервис
    func loadRoutes() {
        isLoading = true
        FirestoreService.shared.fetchExploreRoutes { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let r): self?.routes = r
                case .failure(let e):  self?.errorMsg = e.localizedDescription
                }
            }
        }
    }
}
