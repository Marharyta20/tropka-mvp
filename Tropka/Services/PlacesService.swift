import Foundation

// MARK: - PlacePick

/// A place as shown in the route editor's picker — just enough to choose it.
struct PlacePick: Identifiable, Equatable {
    let id: Int
    let name: String
    let address: String?
    let category: PlaceCategory
    let photoURL: URL?
}

// MARK: - CategoryCount

/// How many places sit in each category, for the Explore home tiles.
struct CategoryCount: Identifiable, Equatable {
    let category: PlaceCategory
    let count: Int
    var id: Int { category.rawValue }
}

// MARK: - PlacesService

/// Read access to the curated `places` table.
/// Searching and filtering run server-side: there are a few thousand rows, and
/// pulling them all into memory would be wasteful.
final class PlacesService {
    static let shared = PlacesService()
    private init() {}

    // MARK: - Row

    private struct Row: Decodable {
        let id: Int
        let name: String
        let address: String?
        let lat: Double?
        let lng: Double?
        let ratingScore: Double?
        let ratingReviews: Int?
        let priceRange: String?
        let tags: [String]?
        let photoUrl: String?
        let photoAttribution: String?
        let shortDescription: String?
        let summary: String?
        let summaryAttribution: String?
        let summaryUrl: String?
        let tropkaNotes: String?
        let instagramWebsite: String?
        let googleMapsAttributes: String?
        let sourceUrl: String?
        let openingHours: String?
        let categoryId: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, address, lat, lng, tags
            case ratingScore       = "rating_score"
            case ratingReviews     = "rating_reviews"
            case priceRange        = "price_range"
            case photoUrl          = "photo_url"
            case photoAttribution  = "photo_attribution"
            case shortDescription  = "short_description"
            case summary
            case summaryAttribution = "summary_attribution"
            case summaryUrl = "summary_url"
            case tropkaNotes       = "tropka_notes"
            case instagramWebsite  = "instagram_website"
            case googleMapsAttributes = "google_maps_attributes"
            case sourceUrl         = "source_url"
            case openingHours      = "opening_hours"
            case categoryId        = "category_id"
        }
    }

    private static let pickColumns = "id, name, address, photo_url, category_id"
    private static let fullColumns = """
        id, name, address, lat, lng, rating_score, rating_reviews, price_range, tags, \
        photo_url, photo_attribution, short_description, summary, summary_attribution, \
        summary_url, \
        tropka_notes, instagram_website, \
        source_url, google_maps_attributes, opening_hours, category_id
        """

    // MARK: - Editor picker

    /// An empty query returns the first page alphabetically, so the picker is
    /// never a blank screen waiting for input.
    func search(query: String, limit: Int = 40) async throws -> [PlacePick] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let rows: [Row]
        if trimmed.isEmpty {
            rows = try await supabase
                .from("places")
                .select(Self.pickColumns)
                .eq("is_listed", value: true)
                .order("name")
                .limit(limit)
                .execute()
                .value
        } else {
            rows = try await supabase
                .from("places")
                .select(Self.pickColumns)
                .eq("is_listed", value: true)
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

    // MARK: - Browsable feed

    /// One page of the catalogue. Paging is server-side via `range`, so scrolling
    /// stays cheap no matter how large the table grows.
    func feed(query: String,
              categories: Set<PlaceCategory>,
              sort: PlaceSort,
              offset: Int,
              pageSize: Int = 30) async throws -> [PlaceDetails] {

        // Import noise (bus stops, offices, bare addresses) is flagged, not deleted:
        // routes may still point at it, but it has no business in the catalogue.
        var builder = supabase.from("places").select(Self.fullColumns).eq("is_listed", value: true)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            builder = builder.ilike("name", pattern: "%\(trimmed)%")
        }
        // An empty selection means "no filter" rather than "nothing".
        if !categories.isEmpty, categories.count != PlaceCategory.allCases.count {
            builder = builder.`in`("category_id", values: categories.map(\.rawValue))
        }

        let rows: [Row] = try await builder
            .order(sort.column, ascending: sort.ascending, nullsFirst: false)
            // Without a unique tiebreaker Postgres may order ties differently per
            // request, so page 2 repeats rows from page 1 and silently drops others.
            .order("id", ascending: true)
            .range(from: offset, to: offset + pageSize - 1)
            .execute()
            .value

        return rows.map(Self.map)
    }

    func details(id: Int) async throws -> PlaceDetails {
        let row: Row = try await supabase
            .from("places")
            .select(Self.fullColumns)
            .eq("id", value: id)
            .single()
            .execute()
            .value
        recordView(placeID: id)
        return Self.map(row)
    }

    // MARK: - Popularity

    /// Counts an opening, and is deliberately unable to fail loudly.
    ///
    /// Every route into a place — the detail screen and the map sheet both — goes
    /// through `details`, so this is the one place it needs to live. Detached
    /// rather than awaited: a place opens whether or not a counter moves, and
    /// making the screen wait on a statistic would be the tail wagging the dog.
    ///
    /// Nothing reads the totals yet. The point is that the column is filling up,
    /// so that when "what people actually open" becomes part of picking the place
    /// of the day, there is something to rank by instead of an empty table.
    private func recordView(placeID: Int) {
        Task.detached {
            struct Params: Encodable {
                let placeID: Int
                enum CodingKeys: String, CodingKey { case placeID = "p_place_id" }
            }
            _ = try? await supabase
                .rpc("record_place_view", params: Params(placeID: placeID))
                .execute()
        }
    }

    // MARK: - Near you

    /// Listed places around a coordinate, nearest first.
    ///
    /// A bounding box and a sort in Swift rather than a distance query: that
    /// would mean PostGIS or earthdistance for a box a few streets wide, and the
    /// error a flat approximation makes over one kilometre in Warsaw is a couple
    /// of metres — far below the point at which anyone would notice their
    /// nearest café was the second nearest.
    ///
    /// Only places with a photo come back, filtered here rather than in the
    /// query: this card is mostly photograph, and a grey rectangle at the top of
    /// the home screen is worse than no card. Forty-odd rows are already in
    /// memory by then, so a server-side null check would buy nothing.
    func nearby(latitude: Double,
                longitude: Double,
                radiusMetres: Double = 1_500,
                limit: Int = 60) async throws -> [PlaceDetails] {

        let latitudeSpan = radiusMetres / 111_320
        // Meridians converge, so a degree of longitude is shorter the further
        // from the equator: at Warsaw's latitude about six tenths of a degree of
        // latitude. Without this the box would be far too narrow east to west.
        let longitudeSpan = radiusMetres / (111_320 * cos(latitude * .pi / 180))

        let rows: [Row] = try await supabase
            .from("places")
            .select(Self.fullColumns)
            .eq("is_listed", value: true)
            .gte("lat", value: latitude - latitudeSpan)
            .lte("lat", value: latitude + latitudeSpan)
            .gte("lng", value: longitude - longitudeSpan)
            .lte("lng", value: longitude + longitudeSpan)
            .order("rating_score", ascending: false, nullsFirst: false)
            .limit(limit)
            .execute()
            .value

        return rows
            .map(Self.map)
            .filter { $0.photoURL != nil }
            .sorted { left, right in
                Self.metres(from: (latitude, longitude), to: left)
                    < Self.metres(from: (latitude, longitude), to: right)
            }
    }

    private static func metres(from origin: (lat: Double, lng: Double),
                               to place: PlaceDetails) -> Double {
        guard let lat = place.lat, let lng = place.lng else { return .greatestFiniteMagnitude }
        let dLat = (lat - origin.lat) * 111_320
        let dLng = (lng - origin.lng) * 111_320 * cos(origin.lat * .pi / 180)
        return (dLat * dLat + dLng * dLng).squareRoot()
    }

    /// Public routes that include this place. Row level security keeps other
    /// people's drafts and private routes out of the result.
    func relatedRoutes(placeID: Int) async throws -> [TourRoute] {
        struct RouteStopRow: Decodable { let routes: TourRoute? }

        let rows: [RouteStopRow] = try await supabase
            .from("route_stops")
            .select("routes(*, users(full_name, username, photo_url))")
            .eq("place_id", value: placeID)
            .execute()
            .value

        return rows.compactMap(\.routes)
    }

    // MARK: - Category counts

    /// Reads the `place_category_counts` view — one round trip instead of a
    /// count query per category.
    func categoryCounts() async throws -> [CategoryCount] {
        struct CountRow: Decodable {
            let categoryId: Int
            let placeCount: Int
            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case placeCount = "place_count"
            }
        }

        let rows: [CountRow] = try await supabase
            .from("place_category_counts")
            .select("category_id, place_count")
            .execute()
            .value

        return rows
            .compactMap { row -> CategoryCount? in
                guard let category = PlaceCategory(rawValue: row.categoryId),
                      category != .other
                else { return nil }
                return CategoryCount(category: category, count: row.placeCount)
            }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Mapping

    private static func map(_ row: Row) -> PlaceDetails {
        PlaceDetails(
            id: row.id,
            name: row.name,
            category: row.categoryId.flatMap(PlaceCategory.init(rawValue:)) ?? .other,
            address: row.address,
            lat: row.lat,
            lng: row.lng,
            rating: row.ratingScore ?? 0,
            reviewCount: row.ratingReviews ?? 0,
            priceRange: row.priceRange,
            tags: row.tags ?? [],
            photoURL: row.photoUrl.flatMap(URL.init),
            photoAttribution: row.photoAttribution?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            summary: row.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            summaryAttribution: row.summaryAttribution?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            summaryURL: row.summaryUrl.flatMap(URL.init),
            description: cleanQuote(row.shortDescription),
            highlights: PlaceHighlights.from(json: row.googleMapsAttributes),
            notes: row.tropkaNotes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            link: row.instagramWebsite.flatMap(URL.init),
            sourceURL: row.sourceUrl.flatMap(URL.init),
            openingHoursRaw: row.openingHours
        )
    }

    /// Descriptions were imported as review quotes and arrive wrapped in quotation
    /// marks. The UI renders them as a quote already, so strip the literal ones.
    private static func cleanQuote(_ text: String?) -> String? {
        guard var value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
        else { return nil }
        let quotes = CharacterSet(charactersIn: "\"“”«»")
        value = value.trimmingCharacters(in: quotes).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
