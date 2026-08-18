//
//  Analytics.swift
//  Tropka
//
//  Thin wrapper around PostHog. Nothing else in the app imports PostHog directly,
//  so the vendor stays swappable and every event name lives in one place.
//

import Foundation
import PostHog
import SwiftUI

enum Analytics {

    private(set) static var isEnabled = false

    // MARK: - Setup

    /// Called once from `TropkaApp.init()`.
    /// Reads POSTHOG_API_KEY / POSTHOG_HOST from Info.plist (fed by Secrets.xcconfig).
    /// If no key is configured the whole layer is a silent no-op — nothing breaks locally.
    static func start() {
        guard let key = infoValue("POSTHOG_API_KEY"),
              !key.isEmpty,
              !key.hasPrefix("YOUR_")
        else {
            #if DEBUG
            print("ℹ️ Analytics disabled: POSTHOG_API_KEY is not set in Secrets.xcconfig")
            #endif
            return
        }

        // The host is stored without a scheme because "//" starts a comment in .xcconfig files.
        let rawHost = infoValue("POSTHOG_HOST") ?? "eu.i.posthog.com"
        let host = rawHost.hasPrefix("http") ? rawHost : "https://\(rawHost)"

        let config = PostHogConfig(projectToken: key, host: host)

        config.captureApplicationLifecycleEvents = true  // installs, launches, foreground/background
        config.captureScreenViews = false                // SwiftUI: we send screens explicitly via .trackScreen()
        config.captureElementInteractions = false        // named events read far better than autocapture

        // Session replay — watch how people actually move through the app.
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true      // required for SwiftUI to render correctly
        config.sessionReplayConfig.maskAllTextInputs = true   // never record typing (passwords, emails)
        config.sessionReplayConfig.maskAllImages = false      // route/place photos are public content

        #if DEBUG
        config.debug = true
        config.flushAt = 1  // see events in PostHog immediately while developing
        #endif

        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    private static func infoValue(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Identity

    /// Ties everything the anonymous session did to a real user id.
    static func identify(userID: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.identify(userID, userProperties: properties)
    }

    /// Call on sign-out so the next person on this device is a separate user.
    static func reset() {
        guard isEnabled else { return }
        PostHogSDK.shared.reset()
    }

    // MARK: - Events

    static func screen(_ name: String, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.screen(name, properties: properties)
    }

    static func track(_ event: Event, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}

// MARK: - Event catalogue

/// Every event the app can send, in one list. Names are snake_case and past-tense.
extension Analytics {
    enum Event: String {
        // Auth
        case signedUp           = "signed_up"
        case loggedIn           = "logged_in"
        case authFailed         = "auth_failed"
        case authModeToggled    = "auth_mode_toggled"
        case signedOut          = "signed_out"
        case accountDeleted     = "account_deleted"

        // Navigation
        case tabSwitched        = "tab_switched"

        // Explore
        case exploreSearched    = "explore_searched"
        case exploreTagFiltered = "explore_tag_filtered"
        case exploreRefreshed   = "explore_refreshed"

        // Routes
        case routeOpened        = "route_opened"
        case routeSaved         = "route_saved"
        case routeUnsaved       = "route_unsaved"
        case routeMapOpened     = "route_map_opened"
        case routeStopStepped   = "route_stop_stepped"
        case routeStopOpened    = "route_stop_opened"
        case navigationStarted  = "navigation_started"

        // Route editor
        case routeEditorOpened  = "route_editor_opened"
        case routeCreated       = "route_created"
        case routeUpdated       = "route_updated"
        case routeDeleted       = "route_deleted"
        case routeStatusChanged = "route_status_changed"
        case routeDescriptionOpened = "route_description_opened"
        case routeStopAdded     = "route_stop_added"
        case routeStopAppended  = "route_stop_appended"
        case placeAddedToDraft  = "place_added_to_draft"

        // Reviews
        case reviewFormOpened   = "review_form_opened"
        case reviewSubmitted    = "review_submitted"
        case reviewDeleted      = "review_deleted"

        // Places catalogue
        case placeOpened            = "place_opened"
        case placesSearched         = "places_searched"
        case placeLinkOpened        = "place_link_opened"
        case exploreSectionSwitched = "explore_section_switched"

        // Map
        case mapSearched        = "map_searched"
        case mapPinTapped       = "map_pin_tapped"
        case mapPlaceExpanded   = "map_place_expanded"
        case mapFiltersOpened   = "map_filters_opened"
        case mapFiltersApplied  = "map_filters_applied"
        case mapZoomed          = "map_zoomed"
        case placeRouteTapped   = "place_related_route_tapped"

        // Tips
        case tipOpened          = "tip_opened"

        // Profile & settings
        case profileTabSwitched = "profile_tab_switched"
        case profileShared      = "profile_shared"
        case settingsSaved      = "settings_saved"
    }

    /// Where a route was opened from — lets us compare Explore vs Map vs Profile as entry points.
    enum Source: String {
        case explore
        case map
        case profile
        case placeSheet = "place_sheet"
    }
}

// MARK: - SwiftUI helpers

extension View {
    /// Sends a screen view when this view appears.
    func trackScreen(_ name: String, _ properties: [String: Any] = [:]) -> some View {
        onAppear { Analytics.screen(name, properties) }
    }
}
