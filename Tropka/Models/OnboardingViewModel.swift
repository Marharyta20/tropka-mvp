import Foundation

// MARK: - City

struct City: Identifiable, Equatable, Decodable {
    let id: Int
    let name: String
    let country: String
}

// MARK: - OnboardingViewModel

/// Backs the short setup step a new account goes through.
///
/// Scope was chosen by one rule: ask nothing whose answer changes nothing. An
/// avatar and a username are what the profile shows, and both were being filled
/// in by the system with a blank and `user6246`. A city feeds the map's
/// "open on Warsaw unless you are in Warsaw" logic and matters the moment there
/// is a second city. Interests order Explore and the map chips.
///
/// What is deliberately absent: travel style, pace, budget. Nothing in the app
/// consumes them, and a question that only costs the user time is worse than no
/// question at all.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var username = ""
    @Published var avatar: Avatar?
    @Published var cityID = 1
    @Published var interests: Set<PlaceCategory> = []

    @Published private(set) var cities: [City] = []
    @Published private(set) var categories: [CategoryCount] = []
    @Published var isSaving = false
    @Published var errorMessage: String?

    var canFinish: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Load

    func load() async {
        async let citiesTask = try? fetchCities()
        async let countsTask = try? PlacesService.shared.categoryCounts()
        async let profileTask = try? fetchCurrentUsername()

        let (cities, counts, existing) = await (citiesTask, countsTask, profileTask)
        self.cities = cities ?? [City(id: 1, name: "Warsaw", country: "Poland")]
        self.categories = counts ?? []
        // Prefilled rather than blank: the generated handle is a starting point,
        // and somebody who does not care can move on without typing.
        if username.isEmpty, let existing { username = existing }
    }

    private func fetchCities() async throws -> [City] {
        try await supabase
            .from("cities")
            .select("id, name, country")
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value
    }

    private func fetchCurrentUsername() async throws -> String? {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return nil }
        struct Row: Decodable { let username: String? }
        let row: Row = try await supabase
            .from("users")
            .select("username")
            .eq("id", value: uid)
            .single()
            .execute()
            .value
        return row.username
    }

    // MARK: - Save

    @discardableResult
    func finish() async -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else {
            errorMessage = "Pick a username."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        struct Update: Encodable {
            let username: String
            let photoUrl: String?
            let cityId: Int
            let interests: [Int]
            let onboardedAt: String
            enum CodingKeys: String, CodingKey {
                case username
                case photoUrl = "photo_url"
                case cityId = "city_id"
                case interests
                case onboardedAt = "onboarded_at"
            }
        }

        let picked = interests.sorted { $0.rawValue < $1.rawValue }

        do {
            try await supabase
                .from("users")
                .update(Update(username: handle,
                               photoUrl: avatar?.storedValue,
                               cityId: cityID,
                               interests: picked.map(\.rawValue),
                               onboardedAt: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: uid)
                .execute()

            UserPreferences.shared.markOnboarded(interests: picked, cityID: cityID)
            Analytics.track(.onboardingFinished, [
                "has_avatar": avatar != nil,
                "interests_count": picked.count,
                "city_id": cityID
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
