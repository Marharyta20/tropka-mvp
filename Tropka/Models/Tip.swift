import Foundation

// MARK: - TipPage

/// One screen of a tip. `places` are the catalogue entries the page talks about —
/// without them a tip names a cafe and leaves the reader with nowhere to go.
struct TipPage: Identifiable {
    let id: String
    let imageURL: String
    let header: String
    let body: String
    let footer: String?
    var places: [PlacePick] = []
}

// MARK: - Tip

struct Tip: Identifiable, Equatable {
    let id: String
    let title: String
    let bannerURL: String
    var pages: [TipPage] = []

    /// How many distinct places this tip sends the reader to. Shown on the list
    /// card so the tip reads as a shortcut into the catalogue, not as a blog post.
    var placeCount: Int {
        Set(pages.flatMap { $0.places.map(\.id) }).count
    }

    static func == (lhs: Tip, rhs: Tip) -> Bool {
        lhs.id == rhs.id
    }
}
