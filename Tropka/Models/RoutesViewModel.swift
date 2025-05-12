import Foundation

@MainActor
final class RoutesViewModel: ObservableObject {
  @Published var routes: [Route] = []

  func loadRoutes() {
    FirestoreService.shared.fetchRoutes { [weak self] list in
      DispatchQueue.main.async { self?.routes = list }
    }
  }
}
