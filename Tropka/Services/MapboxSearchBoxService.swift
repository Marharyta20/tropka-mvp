import Foundation
import CoreLocation

// MARK: - Models

/// A single autocomplete suggestion. Deliberately has **no coordinate**:
/// the Search Box API withholds geometry until `/retrieve` is called.
struct SearchBoxSuggestion: Identifiable, Equatable {
    let id = UUID()
    let mapboxID: String
    let name: String
    /// e.g. "Ann Arbor, Michigan 48104, United States"
    let placeFormatted: String?
    let fullAddress: String?
    /// "poi", "address", "place", "category", ...
    let featureType: String
    /// Canonical category, e.g. "coffee_shop". Present for POIs.
    let poiCategory: String?
    /// Metres from the `proximity` point, when one was supplied.
    let distance: Double?

    var subtitle: String? { fullAddress ?? placeFormatted }

    static func == (lhs: SearchBoxSuggestion, rhs: SearchBoxSuggestion) -> Bool {
        lhs.mapboxID == rhs.mapboxID
    }
}

// MARK: - Session

/// Groups `/suggest` calls with the `/retrieve` that follows them.
///
/// Billing is **per session**, not per keystroke: one session covers up to
/// 50 `/suggest` calls plus 1 `/retrieve`, and expires after 2 minutes idle.
/// Getting this wrong is the difference between $3 and $150 per 1,000 searches,
/// so the token is owned here rather than by the view.
actor SearchBoxSession {
    private var token = UUID().uuidString
    private var suggestCount = 0
    private var lastActivity = Date()

    private static let maxSuggestsPerSession = 50
    private static let idleTimeout: TimeInterval = 120

    /// Returns the token to use for the next `/suggest`, rotating it when the
    /// current session is exhausted or has gone stale.
    func tokenForSuggest() -> String {
        let now = Date()
        if suggestCount >= Self.maxSuggestsPerSession || now.timeIntervalSince(lastActivity) > Self.idleTimeout {
            rotate()
        }
        suggestCount += 1
        lastActivity = now
        return token
    }

    /// Token for `/retrieve`. Must match the suggests it follows, otherwise
    /// Mapbox bills the retrieve as a brand new session.
    func tokenForRetrieve() -> String { token }

    /// Call after a successful `/retrieve` — the session is closed at that point.
    func finish() { rotate() }

    private func rotate() {
        token = UUID().uuidString
        suggestCount = 0
        lastActivity = Date()
    }
}

// MARK: - Service

/// Mapbox Search Box API — interactive POI/address autocomplete.
///
/// Two-step flow:
///   1. `/suggest` on every (debounced) keystroke → names only, no coordinates
///   2. `/retrieve` once the user taps a row → coordinates + full detail
///
/// Docs: https://docs.mapbox.com/api/search/search-box/
final class MapboxSearchBoxService {
    static let shared = MapboxSearchBoxService()

    private let accessToken = MapboxToken.value
    private let session = URLSession(configuration: .default)
    private let billingSession = SearchBoxSession()
    private let baseURL = "https://api.mapbox.com/search/searchbox/v1"

    private var language: String {
        Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
    }

    // MARK: Suggest

    /// Fetches autocomplete suggestions. Call this from a debounced context —
    /// see `PlaceSearchView`. Every call consumes one of the session's 50 suggests.
    /// - Parameters:
    ///   - query: Raw user input.
    ///   - proximity: Bias results toward this point (user location or map centre).
    ///   - countries: Optional ISO 3166 alpha-2 filter, e.g. ["cz", "de"].
    ///   - types: Restrict feature types. Defaults to POIs + addresses + places.
    ///   - limit: Up to 10.
    func suggest(
        query: String,
        proximity: CLLocationCoordinate2D? = nil,
        countries: [String]? = nil,
        types: [String] = ["poi", "address", "place"],
        limit: Int = 10
    ) async throws -> [SearchBoxSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !accessToken.isEmpty else { throw MapboxToken.missingTokenError }

        var components = URLComponents(string: "\(baseURL)/suggest")!
        var items: [URLQueryItem] = [
            .init(name: "q", value: trimmed),
            .init(name: "access_token", value: accessToken),
            .init(name: "session_token", value: await billingSession.tokenForSuggest()),
            .init(name: "language", value: language),
            .init(name: "limit", value: String(min(limit, 10))),
            .init(name: "types", value: types.joined(separator: ","))
        ]
        if let proximity {
            items.append(.init(name: "proximity", value: "\(proximity.longitude),\(proximity.latitude)"))
        }
        if let countries, !countries.isEmpty {
            items.append(.init(name: "country", value: countries.joined(separator: ",")))
        }
        components.queryItems = items

        let data = try await get(components.url!)
        return try JSONDecoder().decode(SuggestResponse.self, from: data).suggestions.map {
            SearchBoxSuggestion(
                mapboxID: $0.mapbox_id,
                name: $0.name,
                placeFormatted: $0.place_formatted,
                fullAddress: $0.full_address,
                featureType: $0.feature_type,
                poiCategory: $0.poi_category?.first,
                distance: $0.distance
            )
        }
    }

    // MARK: Retrieve

    /// Resolves a suggestion to a concrete coordinate. Closes the billing session.
    func retrieve(_ suggestion: SearchBoxSuggestion) async throws -> MapboxSearchResult {
        try await retrieve(mapboxID: suggestion.mapboxID)
    }

    /// Resolves a stored `mapbox_id` — this is the call you make later if you
    /// persist IDs rather than POI payloads.
    func retrieve(mapboxID: String) async throws -> MapboxSearchResult {
        guard !accessToken.isEmpty else { throw MapboxToken.missingTokenError }

        let encodedID = mapboxID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mapboxID
        var components = URLComponents(string: "\(baseURL)/retrieve/\(encodedID)")!
        components.queryItems = [
            .init(name: "access_token", value: accessToken),
            .init(name: "session_token", value: await billingSession.tokenForRetrieve()),
            .init(name: "language", value: language)
        ]

        let data = try await get(components.url!)
        await billingSession.finish()

        let decoded = try JSONDecoder().decode(RetrieveResponse.self, from: data)
        guard let feature = decoded.features.first,
              feature.geometry.coordinates.count == 2 else {
            throw NSError(
                domain: "MapboxSearchBox",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No location returned for this result."]
            )
        }

        let props = feature.properties
        return MapboxSearchResult(
            name: props.name,
            coordinate: CLLocationCoordinate2D(
                latitude: feature.geometry.coordinates[1],
                longitude: feature.geometry.coordinates[0]
            ),
            subtitle: props.full_address ?? props.place_formatted,
            mapboxID: props.mapbox_id,
            poiCategory: props.poi_category?.first
        )
    }

    // MARK: Networking

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request, delegate: nil)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "MapboxSearchBox", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from Mapbox."])
        }
        guard (200..<300).contains(http.statusCode) else {
            let message: String
            switch http.statusCode {
            case 401: message = "Mapbox rejected the access token."
            case 422: message = "Mapbox could not process that search query."
            case 429: message = "Search rate limit reached. Try again in a moment."
            default:  message = "Mapbox search failed (HTTP \(http.statusCode))."
            }
            throw NSError(domain: "MapboxSearchBox", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        return data
    }

    // MARK: Wire format

    private struct SuggestResponse: Decodable {
        let suggestions: [Suggestion]
        struct Suggestion: Decodable {
            let name: String
            let mapbox_id: String
            let feature_type: String
            let address: String?
            let full_address: String?
            let place_formatted: String?
            let poi_category: [String]?
            let distance: Double?
        }
    }

    private struct RetrieveResponse: Decodable {
        let features: [Feature]
        struct Feature: Decodable {
            let geometry: Geometry
            let properties: Properties
        }
        struct Geometry: Decodable {
            /// [longitude, latitude]
            let coordinates: [Double]
        }
        struct Properties: Decodable {
            let name: String
            let mapbox_id: String
            let feature_type: String
            let address: String?
            let full_address: String?
            let place_formatted: String?
            let poi_category: [String]?
        }
    }
}
