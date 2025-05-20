import Foundation
import FirebaseFirestore              // Firestore + GeoPoint
import Combine
import MapboxDirections
import CoreLocation

final class TourDetailsViewModel: ObservableObject {

    @Published var stops: [Stop] = []
    @Published var isLoading = false
    @Published var errorMsg: String?
    @Published var routeCoords: [CLLocationCoordinate2D] = []

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
    
    func buildWalkingRoute() {
        let wps = stops.map { Waypoint(coordinate: $0.coordinates.clCoord) }
        
        let opts = RouteOptions(waypoints: wps,
                               profileIdentifier: .walking)
        opts.includesSteps = false
        opts.routeShapeResolution = .full     // нужны все точки поли-линии
        
        Directions.shared.calculate(opts) { [weak self] wps, routes, error in
            if let error = error {
                print("❌ Directions error:", error)
                return
            }
            
            guard
                let route = routes?.first,
                let coords = route.coordinates  // Use coordinates directly from the route
            else { return }
            
            self?.routeCoords = coords
        }
    }
}
