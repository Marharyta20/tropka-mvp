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
        Task {
            do {
                routes = try await SupabaseService.shared.fetchRoutes()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
