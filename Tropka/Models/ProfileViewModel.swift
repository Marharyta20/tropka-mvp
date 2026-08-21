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
    @Published var displayName = ""
    /// True until the profile row has been read once — lets the UI show a
    /// placeholder instead of a fake name.
    @Published var isLoadingProfile = true
    @Published var handle      = ""
    @Published var city        = ""
    @Published var registrationDate: Date?
    /// Raw contents of users.photo_url — see Avatar for how it is interpreted.
    @Published var avatarValue: String?

    // Routes saved from other authors
    @Published var routes: [SavedRoute] = []

    // Routes this user wrote
    @Published var createdRoutes: [TourRoute] = []
    /// Routes the user has marked as walked, newest first.
    @Published var walkedRoutes: [TourRoute] = []

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
        // Cleared here rather than in each fetch: the banner in ProfileView is
        // shared, and a stale message from a failure the user has already
        // retried past would sit there forever.
        errorMessage = nil
        await fetchUserProfile()
        await fetchSavedRoutes()
        await fetchCreatedRoutes()
        await fetchWalkedRoutes()
        loadReviews()
    }

    // MARK: - Profile

    private func fetchUserProfile() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            isLoadingProfile = false
            return
        }
        defer { isLoadingProfile = false }

        struct UserRow: Decodable {
            let fullName: String?
            let username: String?
            let photoUrl: String?
            let registrationDate: Date?
            let cities: CityRow?

            struct CityRow: Decodable { let name: String }

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
                case photoUrl = "photo_url"
                case registrationDate = "registration_date"
                case cities
            }
        }

        do {
            let row: UserRow = try await supabase
                .from("users")
                .select("full_name, username, photo_url, registration_date, cities(name)")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            displayName      = row.fullName ?? "Unknown User"
            handle           = row.username ?? "user"
            avatarValue      = row.photoUrl
            UserPreferences.shared.setAvatar(row.photoUrl)
            city             = row.cities?.name ?? ""
            registrationDate = row.registrationDate
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Avatar

    func setAvatar(_ avatar: Avatar) async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        let previous = avatarValue
        avatarValue = avatar.storedValue      // optimistic, the grid closes immediately
        // Every card in the app that draws this user updates from here.
        UserPreferences.shared.setAvatar(avatar.storedValue)

        struct AvatarUpdate: Encodable {
            let photoUrl: String
            enum CodingKeys: String, CodingKey { case photoUrl = "photo_url" }
        }

        do {
            try await supabase
                .from("users")
                .update(AvatarUpdate(photoUrl: avatar.storedValue))
                .eq("id", value: uid)
                .execute()
            Analytics.track(.avatarChanged, ["avatar": avatar.id])
        } catch {
            avatarValue = previous
            UserPreferences.shared.setAvatar(previous)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Saved routes

    func fetchSavedRoutes() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        // `routes` is optional on purpose: if an author flips their route to
        // private or draft, row level security stops returning it and the embed
        // comes back null. Without this the whole saved list would fail to decode.
        struct SavedRouteRow: Decodable {
            let savedAt: Date?
            let routes: TourRoute?
            enum CodingKeys: String, CodingKey {
                case savedAt = "saved_at"
                case routes
            }
        }

        do {
            let rows: [SavedRouteRow] = try await supabase
                .from("saved_routes")
                .select("saved_at, routes(*, users(full_name, username, photo_url))")
                .eq("user_id", value: uid)
                .order("saved_at", ascending: false)
                .execute()
                .value

            routes = rows.compactMap { row in
                guard let route = row.routes else { return nil }
                return SavedRoute(route: route, savedAt: row.savedAt)
            }
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

    // MARK: - Created routes

    func fetchWalkedRoutes() async {
        do {
            walkedRoutes = try await RouteCompletionService().walkedRoutes()
        } catch {
            errorMessage = error.localizedDescription
        }
        // The ids come from their own query rather than from the list above: a
        // route whose author has since made it private drops out of the embed,
        // but it is still one the user walked, and the badge on it elsewhere
        // should not vanish because of somebody else's edit.
        await WalkedRoutesStore.shared.refresh()
    }

    func fetchCreatedRoutes() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        do {
            createdRoutes = try await SupabaseService.shared.fetchRoutes(authoredBy: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCreated(routeID: String) async {
        do {
            try await RouteEditorService().deleteRoute(routeID: routeID)
            createdRoutes.removeAll { $0.id == routeID }
            Analytics.track(.routeDeleted, ["route_id": routeID])
        } catch {
            errorMessage = error.localizedDescription
        }
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
