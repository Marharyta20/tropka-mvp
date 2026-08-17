import Foundation

// MARK: - PlacePick

/// A place as shown in the picker — just enough to choose it and render a row.
struct PlacePick: Identifiable, Equatable {
    let id: Int
    let name: String
    let address: String?
    let category: PlaceCategory
    let photoURL: URL?
}

// MARK: - PlacesService

/// Read access to the curated `places` table for the route editor.
/// Searching runs server-side: there are a few thousand rows, and pulling them
/// all into memory on every keystroke would be wasteful.
final class PlacesService {
    static let shared = PlacesService()
    private init() {}

    private struct Row: Decodable {
        let id: Int
        let name: String
        let address: String?
        let photoUrl: String?
        let categoryId: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, address
            case photoUrl = "photo_url"
            case categoryId = "category_id"
        }
    }

    private static let columns = "id, name, address, photo_url, category_id"

    /// An empty query returns the first page alphabetically, so the picker is
    /// never a blank screen waiting for input.
    func search(query: String, limit: Int = 40) async throws -> [PlacePick] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let rows: [Row]
        if trimmed.isEmpty {
            rows = try await supabase
                .from("places")
                .select(Self.columns)
                .order("name")
                .limit(limit)
                .execute()
                .value
        } else {
            rows = try await supabase
                .from("places")
                .select(Self.columns)
                .ilike("name", pattern: "%\(trimmed)%")
                .order("name")
                .limit(limit)
                .execute()
                .value
        }

        return rows.map { row in
            PlacePick(
                id: row.id,
                name: row.name,
                address: row.address,
                category: row.categoryId.flatMap(PlaceCategory.init(rawValue:)) ?? .other,
                photoURL: row.photoUrl.flatMap(URL.init)
            )
        }
    }
}
