import Foundation
import Combine

// MARK: - SavedRoute (UI model)

struct SavedRoute: Identifiable {
    let route: TourRoute
    let savedAt: Date?
    var id: String { route.id }
}

// MARK: - ProfileViewModel

@MainActor
class ProfileViewModel: ObservableObject {

    // User info
    @Published var displayName = "Loading..."
    @Published var handle      = ""
    @Published var city        = ""
    @Published var registrationDate: Date?

    // Saved routes
    @Published var routes: [SavedRoute] = []

    // Reviews
    @Published var myReviews: [UserReview] = []

    @Published var errorMessage: String?

    private let reviewSvc = ReviewService()
    private var cancellable: AnyCancellable?

    init() {
        Task { await fetchAll() }

        // Re-fetch saved routes whenever the store updates
        cancellable = SavedRoutesStore.shared.$savedIDs
            .sink { [weak self] _ in
                Task { await self?.fetchSavedRoutes() }
            }
    }

    // MARK: - Load all

    func fetchAll() async {
        await fetchUserProfile()
        await fetchSavedRoutes()
        loadReviews()
    }

    // MARK: - Profile

    private func fetchUserProfile() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        struct UserRow: Decodable {
            let fullName: String?
            let username: String?
            let registrationDate: Date?
            let cities: CityRow?

            struct CityRow: Decodable { let name: String }

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
                case registrationDate = "registration_date"
                case cities
            }
        }

        do {
            let row: UserRow = try await supabase
                .from("users")
                .select("full_name, username, registration_date, cities(name)")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            displayName      = row.fullName ?? "Unknown User"
            handle           = row.username ?? "user"
            city             = row.cities?.name ?? ""
            registrationDate = row.registrationDate
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Saved routes

    func fetchSavedRoutes() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        struct SavedRouteRow: Decodable {
            let savedAt: Date?
            let routes: TourRoute
            enum CodingKeys: String, CodingKey {
                case savedAt = "saved_at"
                case routes
            }
        }

        do {
            let rows: [SavedRouteRow] = try await supabase
                .from("saved_routes")
                .select("saved_at, routes(*)")
                .eq("user_id", value: uid)
                .order("saved_at", ascending: false)
                .execute()
                .value

            routes = rows.map { SavedRoute(route: $0.routes, savedAt: $0.savedAt) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unsave(routeID: String) async {
        if let idx = routes.firstIndex(where: { $0.id == routeID }) {
            routes.remove(at: idx)
        }
        try? await SavedRoutesService().remove(routeID: routeID)
    }

    // MARK: - Reviews

    func loadReviews() {
        Task {
            do   { myReviews = try await reviewSvc.fetchMyReviews() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func update(review: UserReview) async {
        myReviews = myReviews.map { $0.routeID == review.routeID ? review : $0 }
        _ = try? await reviewSvc.upsert(review: review)
    }

    func delete(review: UserReview) async {
        try? await reviewSvc.delete(review: review)
        myReviews.removeAll { $0.id == review.id }
    }

    func create(review: UserReview) async {
        do {
            try await reviewSvc.create(review: review)
            loadReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
