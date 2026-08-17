import Foundation
import Combine
import CoreLocation
import MapboxDirections
import MapboxNavigationCore

@MainActor
final class TourDetailsViewModel: ObservableObject {
    @Published var stops: [Stop] = []
    /// Refreshed copy of the route header. The view is handed an immutable
    /// TourRoute, so after an edit or a status change we re-read it here.
    @Published var route: TourRoute?
    @Published var isLoading = false
    @Published var errorMsg: String? = nil

    @Published var routeCoords: [CLLocationCoordinate2D] = []
    @Published var isSaved = false
    @Published var myReview: UserReview? = nil

    // Navigation v3 needs NavigationRoutes here, not Route/RouteResponse.
    @Published var navigationRoutes: NavigationRoutes?

    private let saveSvc = SavedRoutesService()
    private let reviewSvc = ReviewService()

    private let navigationProvider = NavigationContainer.shared.provider

    func load(routeID: String) async {
        isLoading = true
        errorMsg = nil

        await reloadRoute(routeID: routeID)

        async let savedTask = saveSvc.isSaved(routeID: routeID)
        async let reviewTask = fetchMyReview(routeID: routeID)
        async let stopsTask = fetchStops(routeID: routeID)

        do {
            let (isSaved, review, stops) = try await (savedTask, reviewTask, stopsTask)

            self.isSaved = isSaved
            self.myReview = review
            self.stops = stops

            if !stops.isEmpty {
                await buildWalkingRoute()
            }
        } catch {
            self.errorMsg = error.localizedDescription
        }

        isLoading = false
    }

    func reloadRoute(routeID: String) async {
        route = try? await SupabaseService.shared.fetchRoute(id: routeID)
    }

    func setStatus(routeID: String, status: RouteStatus) async {
        do {
            try await RouteEditorService().setStatus(routeID: routeID, status: status)
            await reloadRoute(routeID: routeID)
            Analytics.track(.routeStatusChanged, ["route_id": routeID, "status": status.rawValue])
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    func saveRoute(routeID: String) async {
        guard !isSaved else { return }
        do {
            try await saveSvc.save(routeID: routeID)
            self.isSaved = true
        } catch {
            self.errorMsg = error.localizedDescription
        }
    }

    func unsaveRoute(routeID: String) async {
        guard isSaved else { return }
        do {
            try await saveSvc.remove(routeID: routeID)
            self.isSaved = false
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

    private func fetchMyReview(routeID: String) async throws -> UserReview? {
        try await reviewSvc.fetchMyReview(routeID: routeID)
    }

    private func fetchStops(routeID: String) async throws -> [Stop] {
        try await SupabaseService.shared.fetchStops(for: routeID)
    }

    // Builds routes the way Navigation SDK v3 expects them — via routingProvider.
    func buildWalkingRoute() async {
        let waypoints = stops.map { Waypoint(coordinate: $0.location) }
        guard waypoints.count >= 2 else { return }

        let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .walking)
        options.includesSteps = true
        options.routeShapeResolution = .full

        do {
            let routingProvider = navigationProvider.mapboxNavigation.routingProvider()
            let result = try await routingProvider.calculateRoutes(options: options).value

            self.navigationRoutes = result

            // Used to draw the route line on the map.
            if let coords = result.mainRoute.route.shape?.coordinates {
                self.routeCoords = coords
            }
        } catch {
            self.errorMsg = error.localizedDescription
            print("RoutingProvider error:", error)
        }
    }
}
