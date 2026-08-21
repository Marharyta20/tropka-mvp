import Combine
import Foundation

// MARK: - WalkedRoutesStore

/// The set of routes the signed-in user has finished.
///
/// A sibling of `SavedRoutesStore`, and for the same reason: any card anywhere
/// in the app can ask "did I walk this?" without its own round trip, and one
/// mark updates every screen showing that route at once — the Explore card, the
/// profile row and the route screen do not each have to find out separately.
@MainActor
final class WalkedRoutesStore: ObservableObject {
    static let shared = WalkedRoutesStore()

    @Published private(set) var walkedIDs: Set<String> = []

    private init() {
        Task { await refresh() }

        // Re-read on sign-in, drop everything on sign-out: one device can hold
        // two people's sessions over its lifetime.
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if session != nil {
                    await refresh()
                } else {
                    walkedIDs = []
                }
            }
        }
    }

    func contains(_ routeID: String) -> Bool {
        walkedIDs.contains(routeID)
    }

    func refresh() async {
        guard supabase.auth.currentUser != nil else {
            walkedIDs = []
            return
        }

        do {
            walkedIDs = Set(try await RouteCompletionService().walkedRouteIDs())
        } catch {
            // Keep what we already know. A failed fetch is not "walked nothing" —
            // clearing here would un-mark every route the moment the network
            // hiccups, which is exactly the bug SavedRoutesStore used to have.
            print("WalkedRoutesStore: refresh failed:", error)
        }
    }

    /// Applied straight after a successful mark or unmark, so the badge appears
    /// without waiting for another round trip.
    func set(_ walked: Bool, routeID: String) {
        if walked {
            walkedIDs.insert(routeID)
        } else {
            walkedIDs.remove(routeID)
        }
    }
}
