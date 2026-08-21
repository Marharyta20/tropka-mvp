import Foundation

// MARK: - TipsViewModel

/// Loads tips, their pages and the catalogue entries each page links to — one
/// query, three levels of embed, so opening a tip needs no further round trip.
@MainActor
final class TipsViewModel: ObservableObject {
    @Published var tips: [Tip] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    /// False until the first page has come back. Without it the tab rendered
    /// "Nothing found — try a different word" in the moment before the first
    /// request had even started, to a user who had searched for nothing.
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    private var hasMore = true
    private let firstPageSize = 20
    private let nextPageSize = 10

    private static let columns = """
        id, title, banner_url, \
        tip_pages(id, order_index, header, body, footer, image_url, \
        tip_page_links(position, places(id, name, address, photo_url, category_id)))
        """

    // MARK: - Row types

    private struct TipRow: Decodable {
        let id: String
        let title: String
        let bannerUrl: String?
        let tipPages: [PageRow]?

        struct PageRow: Decodable {
            let id: String
            let orderIndex: Int
            let header: String?
            let body: String?
            let footer: String?
            let imageUrl: String?
            let links: [LinkRow]?

            enum CodingKeys: String, CodingKey {
                case id
                case orderIndex = "order_index"
                case header, body, footer
                case imageUrl = "image_url"
                case links = "tip_page_links"
            }
        }

        /// A link can point at a route instead of a place, so `places` is optional.
        struct LinkRow: Decodable {
            let position: Int
            let places: PlaceRow?
        }

        struct PlaceRow: Decodable {
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

        enum CodingKeys: String, CodingKey {
            case id, title
            case bannerUrl = "banner_url"
            case tipPages = "tip_pages"
        }
    }

    // MARK: - Load first page

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let rows: [TipRow] = try await supabase
                .from("tips")
                .select(Self.columns)
                .eq("is_published", value: true)
                .order("title")
                .limit(firstPageSize)
                .execute()
                .value

            tips = rows.map(Self.makeTip)
            hasMore = rows.count == firstPageSize
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load next page

    func fetchMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let rows: [TipRow] = try await supabase
                .from("tips")
                .select(Self.columns)
                .eq("is_published", value: true)
                .order("title")
                .range(from: tips.count, to: tips.count + nextPageSize - 1)
                .execute()
                .value

            tips.append(contentsOf: rows.map(Self.makeTip))
            hasMore = rows.count == nextPageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mapping

    private static func makeTip(_ row: TipRow) -> Tip {
        var tip = Tip(id: row.id, title: row.title, bannerURL: row.bannerUrl ?? "")
        tip.pages = (row.tipPages ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { page in
                TipPage(
                    id: page.id,
                    imageURL: page.imageUrl ?? "",
                    header: page.header ?? "",
                    body: page.body ?? "",
                    footer: page.footer,
                    places: (page.links ?? [])
                        .sorted { $0.position < $1.position }
                        .compactMap { $0.places }
                        .map { place in
                            PlacePick(
                                id: place.id,
                                name: place.name,
                                address: place.address,
                                category: place.categoryId.flatMap(PlaceCategory.init(rawValue:)) ?? .other,
                                photoURL: place.photoUrl.flatMap(URL.init)
                            )
                        }
                )
            }
        return tip
    }
}
