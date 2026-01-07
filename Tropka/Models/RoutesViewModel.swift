import Foundation
import Combine

@MainActor
final class RoutesViewModel: ObservableObject {
    @Published var routes: [TourRoute] = []
    @Published var isLoading = false
    @Published var errorMsg: String?

    func loadRoutes() {
        isLoading = true
        errorMsg = nil
        
        Task{
            do {
                let fetchedRoutes = try await FirestoreService.shared.fetchRoutes()
                self.routes = fetchedRoutes
            } catch {
                self.errorMsg = error.localizedDescription
            }
            
            self.isLoading = false
        }
    }
}
