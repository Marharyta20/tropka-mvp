import Foundation
import FirebaseFirestore
import Combine
import MapboxDirections
import CoreLocation

@MainActor
final class TourDetailsViewModel: ObservableObject {
    @Published var stops: [Stop] = []
    @Published var isLoading = false
    @Published var errorMsg: String? = nil
    
    @Published var routeCoords: [CLLocationCoordinate2D] = []
    @Published var isSaved = false
    @Published var myReview: UserReview? = nil
    
    private let saveSvc = SavedRoutesService()
    private let reviewSvc = ReviewService()
    
    // Прямой вызов сервиса
    func load(routeID: String) async {
        isLoading = true
        errorMsg = nil
        
        // Загружаем всё параллельно
        async let savedTask = saveSvc.isSaved(routeID: routeID)
        async let reviewTask = fetchMyReview(routeID: routeID)
        async let stopsTask = fetchStops(routeID: routeID)
        
        do {
            let (isSaved, review, stops) = try await (savedTask, reviewTask, stopsTask)
            
            self.isSaved = isSaved
            self.myReview = review
            self.stops = stops
            
            // Если есть остановки, строим линию маршрута
            if !stops.isEmpty {
                buildWalkingRoute()
            }
            
        } catch {
            self.errorMsg = error.localizedDescription
        }
        self.isLoading = false
    }
    
    // MARK: - Actions
    
    func saveRoute(routeID: String) async {
        guard !isSaved else { return }
        do {
            try await saveSvc.save(routeID: routeID)
            self.isSaved = true
        } catch {
            self.errorMsg = error.localizedDescription
        }
    }
    
    func saveReview(_ review: UserReview) async {
        do {
            self.myReview = try await reviewSvc.upsert(review: review)
        } catch {
            print("Error saving review: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func fetchMyReview(routeID: String) async throws -> UserReview? {
        try await reviewSvc.fetchMyReview(routeID: routeID)
    }
    
    private func fetchStops(routeID: String) async throws -> [Stop] {
        return try await FirestoreService.shared.fetchStops(for: routeID)
    }
    
        func buildWalkingRoute() {
            // Убедитесь, что Stop.swift имеет var location: CLLocationCoordinate2D
            let wps = stops.map { Waypoint(coordinate: $0.location) }
            
            guard !wps.isEmpty else { return }
            
            let opts = RouteOptions(waypoints: wps, profileIdentifier: .walking)
            opts.includesSteps = false
            opts.routeShapeResolution = .full // Это важно, чтобы сервер вернул геометрию
            
            Directions.shared.calculate(opts) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        // ИСПРАВЛЕНИЕ ЗДЕСЬ:
                        // Берем .shape?.coordinates вместо просто .coordinates
                        if let route = response.routes?.first,
                           let coords = route.shape?.coordinates {
                            
                            self?.routeCoords = coords
                        }
                        
                    case .failure(let error):
                        print("Mapbox Error: \(error.localizedDescription)")
                    }
                }
            }
        }
}
