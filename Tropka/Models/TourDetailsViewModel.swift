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
    /// Whether the signed-in user has marked this route as walked. Separate from
    /// `isSaved` on purpose: a bookmark says "I might", this says "I did".
    @Published var isWalked = false
    @Published var myReview: UserReview? = nil
    /// Every review on this route, author included — shown to everyone.
    @Published var reviews: [UserReview] = []

    // Navigation v3 needs NavigationRoutes here, not Route/RouteResponse.
    @Published var navigationRoutes: NavigationRoutes?

    private let saveSvc = SavedRoutesService()
    private let walkSvc = RouteCompletionService()
    private let reviewSvc = ReviewService()

    private let navigationProvider = NavigationContainer.shared.provider

    func load(routeID: String) async {
        isLoading = true
        errorMsg = nil

        await reloadRoute(routeID: routeID)
        await loadReviews(routeID: routeID)

        async let savedTask = saveSvc.isSaved(routeID: routeID)
        async let walkedTask = try? walkSvc.isWalked(routeID: routeID)
        async let reviewTask = fetchMyReview(routeID: routeID)
        async let stopsTask = fetchStops(routeID: routeID)

        do {
            let (isSaved, isWalked, review, stops) = try await (savedTask, walkedTask, reviewTask, stopsTask)

            self.isSaved = isSaved
            self.isWalked = isWalked ?? false
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

    func loadReviews(routeID: String) async {
        reviews = (try? await reviewSvc.fetchReviews(routeID: routeID)) ?? []
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

    /// Marks the route walked, or takes the mark back.
    ///
    /// The flag flips first and rolls back on failure, like the bookmark; the
    /// route header is then re-read so `completed_count` on screen matches what
    /// the trigger just wrote.
    func setWalked(_ walked: Bool, routeID: String) async {
        guard walked != isWalked else { return }
        let previous = isWalked
        isWalked = walked
        do {
            if walked {
                try await walkSvc.markWalked(routeID: routeID)
            } else {
                try await walkSvc.unmarkWalked(routeID: routeID)
            }
            // Every card showing this route updates from here, without refetching.
            // Nothing on screen reads completed_count any more, so there is no
            // reason to re-read the route header after a mark.
            WalkedRoutesStore.shared.set(walked, routeID: routeID)
            Analytics.track(walked ? .routeWalked : .routeUnwalked, ["route_id": routeID])
        } catch {
            isWalked = previous
            errorMsg = error.localizedDescription
        }
    }

    func saveReview(_ review: UserReview) async {
        do {
            self.myReview = try await reviewSvc.upsert(review: review)
            await loadReviews(routeID: review.routeID)
        } catch {
            errorMsg = error.localizedDescription
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
        let waypoints = stops.compactMap(\.location).map { Waypoint(coordinate: $0) }
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
