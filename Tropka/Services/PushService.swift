import Combine
import UIKit
import UserNotifications

// MARK: - PushService

/// Permission, registration and the device token.
///
/// The permission is deliberately *not* asked for at launch. A prompt that
/// arrives before the person knows what the app is gets denied, and iOS only
/// ever shows it once — a "no" here is permanent short of a trip to Settings.
/// It is asked at the moment it means something: right after somebody publishes
/// their first route, when "tell me when someone reviews it" is an offer rather
/// than an interruption.
@MainActor
final class PushService: NSObject, ObservableObject {
    static let shared = PushService()

    /// What iOS thinks. `.notDetermined` means the prompt has never been shown.
    @Published private(set) var systemStatus: UNAuthorizationStatus = .notDetermined
    /// What the user chose inside Tropka. Both must be true for anything to send.
    @Published private(set) var isEnabled = false

    private override init() { super.init() }

    // MARK: - Setup

    /// Called once at launch. Registers for a token if we already have
    /// permission, and never prompts.
    func start() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemStatus = settings.authorizationStatus
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            // Apple: never cache the token. Ask the system on every launch — it
            // changes when the OS is reinstalled or a backup is restored.
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Asking

    /// Returns false when the user says no, or has said no before.
    @discardableResult
    func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()

        // Already refused. Prompting again does nothing at all — iOS will not
        // show the sheet a second time — so the caller has to send them to
        // Settings instead of pretending it asked.
        guard settings.authorizationStatus != .denied else {
            systemStatus = .denied
            return false
        }

        do {
            let granted = try await centre.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
            Analytics.track(.pushPermissionAnswered, ["granted": granted])
            if granted { await setEnabled(true) }
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    /// The in-app switch, which is not the same thing as the OS permission: a
    /// person may allow notifications at the system level and still want Tropka
    /// to stop, without hunting through Settings.
    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }

        struct Update: Encodable {
            let notificationsEnabled: Bool
            enum CodingKeys: String, CodingKey { case notificationsEnabled = "notifications_enabled" }
        }

        do {
            try await supabase
                .from("users")
                .update(Update(notificationsEnabled: enabled))
                .eq("id", value: uid)
                .execute()
        } catch {
            print("PushService: could not store the preference:", error)
        }
    }

    func loadEnabled() async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        struct Row: Decodable {
            let notificationsEnabled: Bool?
            enum CodingKeys: String, CodingKey { case notificationsEnabled = "notifications_enabled" }
        }
        let row: Row? = try? await supabase
            .from("users")
            .select("notifications_enabled")
            .eq("id", value: uid)
            .single()
            .execute()
            .value
        isEnabled = row?.notificationsEnabled ?? false
    }

    // MARK: - Token

    func store(deviceToken: Data) async {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        struct TokenRow: Encodable {
            let userId: String
            let token: String
            let platform: String
            let environment: String
            let lastSeenAt: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case token, platform, environment
                case lastSeenAt = "last_seen_at"
            }
        }

        do {
            try await supabase
                .from("device_tokens")
                .upsert(TokenRow(userId: uid,
                                 token: token,
                                 platform: "ios",
                                 environment: Self.environment,
                                 lastSeenAt: ISO8601DateFormatter().string(from: Date())),
                        onConflict: "token")
                .execute()
        } catch {
            print("PushService: could not store the token:", error)
        }
    }

    /// A debug build talks to APNs' sandbox and a release build to production.
    /// They are separate services with separate tokens: send a sandbox token to
    /// the production endpoint and APNs answers BadDeviceToken, which is the
    /// least helpful error message in the business.
    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

// MARK: - Foreground presentation

extension PushService: UNUserNotificationCenterDelegate {
    /// Shown even while the app is open. Without this iOS silently swallows a
    /// notification that arrives in the foreground, which reads as "push is
    /// broken" during exactly the testing where it matters.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Read the payload out here, on the delegate's own thread. `userInfo` is
        // `[AnyHashable: Any]`, which is not Sendable, so carrying the dictionary
        // itself across to the main actor is an error under Swift 6 — a plain
        // `String` crosses freely.
        let type = (response.notification.request.content.userInfo["type"] as? String) ?? "unknown"
        await MainActor.run {
            Analytics.track(.pushOpened, ["type": type])
        }
    }
}

// MARK: - App delegate

/// SwiftUI has no hook for the two APNs callbacks, so this is the smallest
/// possible delegate rather than a home for anything else.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushService.shared.store(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Nothing to do and nothing to tell the user: no signal, or no push
        // entitlement in this build. The next launch tries again.
        print("PushService: APNs registration failed:", error.localizedDescription)
    }
}
