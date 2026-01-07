import SwiftUI
import Combine

@MainActor // Весь код выполняется в главном потоке (для UI)
class ExploreViewModel: ObservableObject {
    
    @Published var routes: [TourRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Поисковой запрос
    @Published var searchText = ""
    
    private var allRoutes: [TourRoute] = [] // Храним копию для фильтрации
    
    init() {
        // Загружаем данные сразу при создании
        loadRoutes()
    }
    
    func loadRoutes() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Одна строчка вместо огромного блока кода!
                let fetchedRoutes = try await FirestoreService.shared.fetchRoutes()
                
                self.allRoutes = fetchedRoutes
                self.routes = fetchedRoutes
                
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
            self.isLoading = false
        }
    }
    
    // Простая фильтрация (Smart Search)
    func filterRoutes() {
        if searchText.isEmpty {
            routes = allRoutes
        } else {
            routes = allRoutes.filter { route in
                route.title.localizedCaseInsensitiveContains(searchText) ||
                route.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}
