import Foundation

// MARK: - Route model (table: public.routes)

struct TourRoute: Identifiable, Equatable, Codable {
    let id: String          // uuid stored as string
    let authorUID: String
    /// Display name of the author, from the embedded users row.
    /// nil when the query did not ask for `users(...)`.
    let authorName: String?
    /// Raw users.photo_url of the author — feed it straight to AvatarView.
    let authorAvatar: String?
    let title: String
    /// Long-form text about the route. Surfaced behind a control on the detail
    /// screen rather than inline, so the header stays scannable.
    let description: String?
    let status: RouteStatus
    let duration: Int       // minutes
    let rating: Double
    let reviewCount: Int
    let stopsCount: Int
    /// How many people have marked this route as walked. Maintained by a trigger
    /// on `route_completions`, so it costs nothing to read here.
    let completedCount: Int
    let tags: [String]
    let thumbnailURL: URL?  // decoded from thumbnail_url text column

    /// True when the signed-in user wrote this route.
    var isMine: Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return false }
        return authorUID.caseInsensitiveCompare(uid) == .orderedSame
    }

    // MARK: Codable

    /// Shape of the embedded `users(full_name, username, photo_url)` join.
    private struct AuthorRow: Decodable {
        let fullName: String?
        let username: String?
        let photoUrl: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case username
            case photoUrl = "photo_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorUID   = "author_uid"
        case author      = "users"
        case title
        case description
        case status
        case duration
        case rating
        case reviewCount = "review_count"
        case stopsCount  = "stops_count"
        case completedCount = "completed_count"
        case tags
        case thumbnailURL = "thumbnail_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        authorUID   = (try? c.decodeIfPresent(String.self, forKey: .authorUID)) ?? ""
        title       = try c.decode(String.self, forKey: .title)
        let rawDescription = (try? c.decodeIfPresent(String.self, forKey: .description))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        description = (rawDescription?.isEmpty == false) ? rawDescription : nil
        // Older queries that don't select status still decode; treat them as public.
        status      = (try? c.decodeIfPresent(RouteStatus.self, forKey: .status)) ?? .public
        duration    = (try? c.decodeIfPresent(Int.self, forKey: .duration)) ?? 0
        rating      = (try? c.decodeIfPresent(Double.self, forKey: .rating)) ?? 0
        reviewCount = (try? c.decodeIfPresent(Int.self, forKey: .reviewCount)) ?? 0
        stopsCount  = (try? c.decodeIfPresent(Int.self, forKey: .stopsCount)) ?? 0
        completedCount = (try? c.decodeIfPresent(Int.self, forKey: .completedCount)) ?? 0
        tags        = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let urlStr  = try? c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        thumbnailURL = urlStr.flatMap(URL.init)

        let author = try? c.decodeIfPresent(AuthorRow.self, forKey: .author)
        authorAvatar = author?.photoUrl
        let fullName = author?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fullName, !fullName.isEmpty {
            authorName = fullName
        } else {
            authorName = author?.username
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorUID, forKey: .authorUID)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(status, forKey: .status)
        try c.encode(duration, forKey: .duration)
        try c.encode(rating, forKey: .rating)
        try c.encode(reviewCount, forKey: .reviewCount)
        try c.encode(stopsCount, forKey: .stopsCount)
        try c.encode(completedCount, forKey: .completedCount)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(thumbnailURL?.absoluteString, forKey: .thumbnailURL)
        // authorName and authorAvatar are derived from a join, never written back.
    }

    static func == (lhs: TourRoute, rhs: TourRoute) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.title == rhs.title
    }
}
