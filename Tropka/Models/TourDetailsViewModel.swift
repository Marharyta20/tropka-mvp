import Foundation
import FirebaseFirestore              // Firestore + GeoPoint
import Combine
import MapboxDirections
import CoreLocation

final class TourDetailsViewModel: ObservableObject {
    
    // MARK: - Published state (UI-binding)

    @Published var stops:        [Stop]                     = []
    @Published var isLoading                             = false
    @Published var errorMsg:      String?                 = nil

    @Published var routeCoords:  [CLLocationCoordinate2D] = []
    @Published var isSaved                               = false

    @Published var myReview:     UserReview?              = nil
    
    // ──────────────────────────────────────────────
    // MARK: - Private helpers

    private let saveSvc   = SavedRoutesService()
    private let reviewSvc = ReviewService()
    private var currentRouteID: String?
    
    // ──────────────────────────────────────────────
       // MARK: - Public API
    @MainActor
    func load(routeID: String) async {
        currentRouteID = routeID

        async let saved  = saveSvc.isSaved(routeID: routeID)          // non-throwing
        async let review = fetchMyReview(routeID: routeID)            // throws
        async let stops  = fetchStops(routeID: routeID)               // throws

        do {
            let savedResult = await saved
            let reviewResult = try await review
            let stopsResult = try await stops
            
            isSaved = savedResult
            myReview = reviewResult
            self.stops = stopsResult
            
        } catch {
            errorMsg = error.localizedDescription
        }
    }
    
    /// Save the whole route to “Your Routes”
    func saveRoute() async {
        guard let id = currentRouteID, !isSaved else { return }
        do {
            try await saveSvc.save(routeID: id)
            isSaved = true           // optimistic UI update
        } catch {
            errorMsg = error.localizedDescription
        }
    }
    
    /// Create **or** update review (if one already exists)
    @MainActor
    func saveReview(_ review: UserReview) async {
        do {
            // upsert = create OR update
            myReview = try await reviewSvc.upsert(review: review)
        } catch {
            print("⚠️ Review save:", error)
        }
    }

    
    // ──────────────────────────────────────────────
    // MARK: - Private helpers
    private func fetchMyReview(routeID: String) async throws -> UserReview? {
        try await reviewSvc.fetchMyReview(routeID: routeID)
    }

    /// Async re-implementation of the old callback version
    private func fetchStops(routeID: String) async throws -> [Stop] {
        try await withCheckedThrowingContinuation { cont in
            FirestoreService.shared.fetchStops(for: routeID) { result in
                switch result {
                case .success(let stops): cont.resume(returning: stops)
                case .failure(let err)  : cont.resume(throwing: err)
                }
            }
        }
    }
    
    
    
    
    
//    func loadMyReview(routeID: String) async {
//        do {
//            myReview = try await reviewSvc.fetchMyReview(routeID: routeID)
//        } catch {
//            print("⚠️ Review load:", error)
//        }
//    }

//    // 3) create / update в одной точке
//    @MainActor
//    func saveReview(_ review: UserReview) async {
//        do {
//            if myReview == nil {
//                try await reviewSvc.create(review: review)
//            } else {
//                try await reviewSvc.update(review: review)
//            }
//            myReview = review                   // обновляем паблишед-свойство
//        } catch {
//            print("⚠️ Review save:", error)
//        }
//    }

//    func load(routeID: String) async {
//        currentRouteID = routeID
//        isSaved = await saveSvc.isSaved(routeID: routeID)
//        // plus existing loadStops…
//    }

//    @MainActor
//    func save() async {
//        guard let id = currentRouteID else { return }
//        try? await saveSvc.save(routeID: id)
//        isSaved = true
//    }
//
//
//    /// Loads all stops for a given route (sub-collection `/stops`)
//    func loadStops(routeID: String) {
//        isLoading = true; errorMsg = nil
//        FirestoreService.shared.fetchStops(for: routeID) { [weak self] res in
//            DispatchQueue.main.async {
//                self?.isLoading = false
//                switch res {
//                case .success(let s): self?.stops = s
//                case .failure(let e): self?.errorMsg = e.localizedDescription
//                }
//            }
//        }
//    }
    
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
