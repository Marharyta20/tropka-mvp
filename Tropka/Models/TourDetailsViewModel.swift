import Foundation
import FirebaseFirestore              // Firestore + GeoPoint
import Combine
import MapboxDirections
import CoreLocation

final class TourDetailsViewModel: ObservableObject {
    @Published var stops:      [Stop]                = []
    @Published var isLoading                        = false
    @Published var errorMsg:   String?              = nil

    @Published var routeCoords: [CLLocationCoordinate2D] = []
    @Published var isSaved                         = false

    @Published var myReview:    UserReview?           = nil

    private let saveSvc   = SavedRoutesService()
    private let reviewSvc = ReviewService()
    private var currentRouteID: String?

    /// Загружает сразу три сущности: сохранённость, отзыв и список стопов
    @MainActor
    func load(routeID: String) async {
        currentRouteID = routeID

        async let saved  = saveSvc.isSaved(routeID: routeID)          // non-throwing
        async let review = fetchMyReview(routeID: routeID)            // throws
        async let stops  = fetchStops(routeID: routeID)               // throws

        do {
            let savedResult  = await saved
            let reviewResult = try await review
            let stopsResult  = try await stops

            isSaved  = savedResult
            myReview = reviewResult
            self.stops = stopsResult

        } catch {
            errorMsg = error.localizedDescription
        }
    }

    /// Сохраняет маршрут (отмечает `isSaved = true` в профиле)
    func saveRoute() async {
        guard let id = currentRouteID, !isSaved else { return }
        do {
            try await saveSvc.save(routeID: id)
            isSaved = true
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    /// Сохраняет новый отзыв или обновляет существующий (upsert)
    @MainActor
    func saveReview(_ review: UserReview) async {
        do {
            myReview = try await reviewSvc.upsert(review: review)
        } catch {
            print("⚠️ Review save:", error)
        }
    }

    // MARK: — private helpers

    private func fetchMyReview(routeID: String) async throws -> UserReview? {
        try await reviewSvc.fetchMyReview(routeID: routeID)
    }

    /// callback → async/await обёртка
    private func fetchStops(routeID: String) async throws -> [Stop] {
        try await withCheckedThrowingContinuation { cont in
            FirestoreService.shared.fetchStops(for: routeID) { result in
                switch result {
                case .success(let stops):  cont.resume(returning: stops)
                case .failure(let err):    cont.resume(throwing: err)
                }
            }
        }
    }

    func buildWalkingRoute() {
        let wps = stops.map { Waypoint(coordinate: $0.coordinates.clCoord) }
        let opts = RouteOptions(waypoints: wps, profileIdentifier: .walking)
        opts.includesSteps = false
        opts.routeShapeResolution = .full

        Directions.shared.calculate(opts) { [weak self] _, routes, error in
            if let error = error {
                print("❌ Directions error:", error)
                return
            }
            guard let route = routes?.first, let coords = route.coordinates else { return }
            self?.routeCoords = coords
        }
    }
}
