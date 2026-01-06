import Foundation
import CoreLocation
import UIKit

struct MapboxSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let subtitle: String?
}

final class MapboxSearchService {
    static let shared = MapboxSearchService()

    // Tries to read token from Info.plist key `MAPBOX_ACCESS_TOKEN` first.
    // If missing, falls back to an empty string (developer must set it).
    private let accessToken: String = {
        if let token = Bundle.main.object(forInfoDictionaryKey: "MAPBOX_ACCESS_TOKEN") as? String, !token.isEmpty {
            return token
        }
        return "" // TODO: Set your Mapbox access token in Info.plist under MAPBOX_ACCESS_TOKEN
    }()

    private let session = URLSession(configuration: .default)

    /// Performs a forward geocoding search against Mapbox Geocoding API.
    /// - Parameters:
    ///   - query: User-entered query string.
    ///   - proximity: Optional proximity to bias results (user location, etc.).
    ///   - limit: Max number of results (default 10).
    func search(query: String, proximity: CLLocationCoordinate2D? = nil, limit: Int = 10) async throws -> [MapboxSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard !accessToken.isEmpty else {
            throw NSError(domain: "MapboxSearchService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Mapbox access token. Set MAPBOX_ACCESS_TOKEN in Info.plist."])
        }

        // URL encode query
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var components = URLComponents(string: "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json")!
        var items: [URLQueryItem] = [
            .init(name: "access_token", value: accessToken),
            .init(name: "autocomplete", value: "true"),
            .init(name: "limit", value: String(limit)),
            .init(name: "language", value: Locale.preferredLanguages.first ?? "en")
        ]
        if let p = proximity {
            items.append(.init(name: "proximity", value: String(format: "%.6f,%.6f", p.longitude, p.latitude)))
        }
        components.queryItems = items

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "MapboxSearchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mapbox API error"])
        }

        // Minimal JSON decoding for features
        struct GeoJSON: Decodable { let features: [Feature] }
        struct Feature: Decodable {
            let place_name: String
            let text: String
            let center: [Double] // [lon, lat]
            let properties: Properties?
        }
        struct Properties: Decodable { let address: String? }

        let decoded = try JSONDecoder().decode(GeoJSON.self, from: data)
        return decoded.features.compactMap { f in
            guard f.center.count == 2 else { return nil }
            let coord = CLLocationCoordinate2D(latitude: f.center[1], longitude: f.center[0])
            let subtitle = f.properties?.address ?? f.place_name
            return MapboxSearchResult(name: f.text, coordinate: coord, subtitle: subtitle)
        }
    }
}
