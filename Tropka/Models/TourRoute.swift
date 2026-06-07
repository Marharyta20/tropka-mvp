import Foundation

// MARK: - Route model (table: public.routes)

struct TourRoute: Identifiable, Equatable, Codable {
    let id: String          // uuid stored as string
    let authorUID: String
    let title: String
    let duration: Int       // minutes
    let isFree: Bool
    let price: Double?
    let rating: Double
    let reviewCount: Int
    let stopsCount: Int
    let tags: [String]
    let thumbnailURL: URL?  // decoded from thumbnail_url text column

    var isActuallyFree: Bool { isFree || (price ?? 0) == 0 }

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case id
        case authorUID   = "author_uid"
        case title
        case duration
        case isFree      = "is_free"
        case price
        case rating
        case reviewCount = "review_count"
        case stopsCount  = "stops_count"
        case tags
        case thumbnailURL = "thumbnail_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        authorUID   = (try? c.decodeIfPresent(String.self, forKey: .authorUID)) ?? ""
        title       = try c.decode(String.self, forKey: .title)
        duration    = (try? c.decodeIfPresent(Int.self, forKey: .duration)) ?? 0
        isFree      = (try? c.decodeIfPresent(Bool.self, forKey: .isFree)) ?? true
        price       = try? c.decodeIfPresent(Double.self, forKey: .price)
        rating      = (try? c.decodeIfPresent(Double.self, forKey: .rating)) ?? 0
        reviewCount = (try? c.decodeIfPresent(Int.self, forKey: .reviewCount)) ?? 0
        stopsCount  = (try? c.decodeIfPresent(Int.self, forKey: .stopsCount)) ?? 0
        tags        = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let urlStr  = try? c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        thumbnailURL = urlStr.flatMap(URL.init)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorUID, forKey: .authorUID)
        try c.encode(title, forKey: .title)
        try c.encode(duration, forKey: .duration)
        try c.encode(isFree, forKey: .isFree)
        try c.encodeIfPresent(price, forKey: .price)
        try c.encode(rating, forKey: .rating)
        try c.encode(reviewCount, forKey: .reviewCount)
        try c.encode(stopsCount, forKey: .stopsCount)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(thumbnailURL?.absoluteString, forKey: .thumbnailURL)
    }

    static func == (lhs: TourRoute, rhs: TourRoute) -> Bool { lhs.id == rhs.id }
}
