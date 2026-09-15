import Foundation

// MARK: - OnboardingViewModel

/// Backs the short setup step a new account goes through.
///
/// Scope was chosen by one rule: ask nothing whose answer changes nothing.
/// An avatar and a name are what the profile shows, and the avatar was being
/// left blank. Interests order Explore and the map chips.
///
/// What is deliberately absent:
///
/// - **A username.** It appeared in three places — the profile subtitle, the
///   share text, and as a stand-in for an empty name on a route card — and
///   nothing in the app looked anybody up by one. A second identity to invent,
///   keep unique and explain, in exchange for decoration. The column is still
///   there for the day profiles become public and `tropka.app/@rita` means
///   something.
/// - **A city.** `city_id` is read and stored and then read by nobody. It will
///   matter with a second city; asking now only spends the user's time.
/// - **Travel style, pace, budget.** Same rule, never added.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var avatar: Avatar?
    @Published var interests: Set<PlaceCategory> = []

    @Published private(set) var categories: [CategoryCount] = []
    @Published var isSaving = false
    @Published var errorMessage: String?

    var canFinish: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Load

    func load() async {
        async let countsTask = try? PlacesService.shared.categoryCounts()
        async let profileTask = try? fetchCurrentName()

        let (counts, existing) = await (countsTask, profileTask)
        self.categories = counts ?? []
        // Prefilled from what they typed at sign-up rather than blank: somebody
        // who is happy with it can move on without typing it twice.
        if displayName.isEmpty, let existing { displayName = existing }
    }

    private func fetchCurrentName() async throws -> String? {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return nil }
        struct Row: Decodable {
            let fullName: String?
            enum CodingKeys: String, CodingKey { case fullName = "full_name" }
        }
        let row: Row = try await supabase
            .from("users")
            .select("full_name")
            .eq("id", value: uid)
            .single()
            .execute()
            .value
        return row.fullName
    }

    // MARK: - Save

    @discardableResult
    func finish() async -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Tell us what to call you."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        struct Update: Encodable {
            let fullName: String
            let photoUrl: String?
            let interests: [Int]
            let onboardedAt: String
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case photoUrl = "photo_url"
                case interests
                case onboardedAt = "onboarded_at"
            }
        }

        let picked = interests.sorted { $0.rawValue < $1.rawValue }

        do {
            try await supabase
                .from("users")
                .update(Update(fullName: name,
                               photoUrl: avatar?.storedValue,
                               interests: picked.map(\.rawValue),
                               onboardedAt: Self.now))
                .eq("id", value: uid)
                .execute()

            UserPreferences.shared.markOnboarded(interests: picked)
            Analytics.track(.onboardingFinished, [
                "has_avatar": avatar != nil,
                "interests_count": picked.count
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Skip

    /// Skip used to call the view's `onFinish` and nothing else — which read the
    /// flag back out of the database, found `onboarded_at` still null, and put
    /// the cover straight back up. The button did nothing at all.
    ///
    /// So it writes the one field that means "do not ask again", and no others:
    /// skipping is a decision to keep the profile as it is, not to blank it.
    ///
    /// A failure is reported rather than swallowed. The screen cannot close
    /// without that write landing, so a silent failure would look exactly like
    /// the bug this replaces.
    @discardableResult
    func skip() async -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }

        struct Skipped: Encodable {
            let onboardedAt: String
            enum CodingKeys: String, CodingKey { case onboardedAt = "onboarded_at" }
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await supabase
                .from("users")
                .update(Skipped(onboardedAt: Self.now))
                .eq("id", value: uid)
                .execute()
            UserPreferences.shared.markOnboarded(interests: [])
            Analytics.track(.onboardingSkipped)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static var now: String {
        ISO8601DateFormatter().string(from: Date())
    }
}
