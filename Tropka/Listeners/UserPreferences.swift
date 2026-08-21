import Combine
import Foundation

// MARK: - UserPreferences

/// What the signed-in user told us about themselves, held once for the whole app.
///
/// Only two things live here, and both earn their place by changing something on
/// screen: the categories they picked (which order the tiles on Explore and the
/// chips on the map) and whether they have been through setup yet.
///
/// Interests order, they never filter. A preference that quietly hides places a
/// user did not ask to hide is how an app ends up feeling smaller than it is.
@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published private(set) var interests: [PlaceCategory] = []
    /// The signed-in user's own `photo_url`, live.
    ///
    /// Every list in the app carries an embedded copy of the author's avatar,
    /// taken when the routes were fetched. Those copies are snapshots: change
    /// your picture and the route you open re-reads it, but the card you came
    /// from still shows the old one until something refetches. For other people
    /// nobody notices; for yourself it reads as a bug, because you just changed
    /// it. `AvatarView` prefers this value whenever it is drawing you.
    @Published private(set) var avatarValue: String?
    @Published private(set) var cityID: Int = 1
    /// Starts false on purpose. A brand-new account flips it to true a moment
    /// after the app opens; a returning user never sees a flicker of setup while
    /// the answer is still being fetched.
    @Published private(set) var needsOnboarding = false

    private init() {
        Task { await refresh() }

        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if session != nil {
                    await refresh()
                } else {
                    interests = []
                    avatarValue = nil
                    needsOnboarding = false
                }
            }
        }
    }

    /// Sorts a list of categories so the user's interests come first, keeping the
    /// original order within each group. `nil` interests leave the list alone.
    func ranked(_ categories: [PlaceCategory]) -> [PlaceCategory] {
        guard !interests.isEmpty else { return categories }
        let picked = Set(interests)
        let mine = categories.filter { picked.contains($0) }
        let rest = categories.filter { !picked.contains($0) }
        return mine + rest
    }

    /// True when this id belongs to the signed-in user.
    func isMe(_ userID: String) -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }
        return uid.caseInsensitiveCompare(userID) == .orderedSame
    }

    /// Called the moment the avatar changes, so every card showing it updates
    /// without refetching anything.
    func setAvatar(_ stored: String?) {
        avatarValue = stored
    }

    func refresh() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            interests = []
            avatarValue = nil
            needsOnboarding = false
            return
        }

        struct Row: Decodable {
            let interests: [Int]?
            let cityId: Int?
            let photoUrl: String?
            let onboardedAt: Date?
            enum CodingKeys: String, CodingKey {
                case interests
                case cityId = "city_id"
                case photoUrl = "photo_url"
                case onboardedAt = "onboarded_at"
            }
        }

        do {
            let row: Row = try await supabase
                .from("users")
                .select("interests, city_id, photo_url, onboarded_at")
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            interests = (row.interests ?? []).compactMap(PlaceCategory.init(rawValue:))
            cityID = row.cityId ?? 1
            avatarValue = row.photoUrl
            needsOnboarding = row.onboardedAt == nil
        } catch {
            // Never strand somebody in setup because a request failed. The worst
            // case of guessing "already done" is an empty profile; the worst case
            // of guessing "not done" is an account that cannot get past a form.
            print("UserPreferences: refresh failed:", error)
        }
    }

    /// Called the moment a sign-up succeeds, so setup appears without waiting for
    /// a round trip to confirm what we already know.
    func markNeedsOnboarding() {
        needsOnboarding = true
    }

    func markOnboarded(interests: [PlaceCategory], cityID: Int) {
        self.interests = interests
        self.cityID = cityID
        needsOnboarding = false
    }
}
