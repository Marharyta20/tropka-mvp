import Foundation

// MARK: - TipsViewModel
// Loads tips + their pages from Supabase in a single query (join).

@MainActor
final class TipsViewModel: ObservableObject {
    @Published var tips:          [Tip] = []
    @Published var isLoading      = false
    @Published var isLoadingMore  = false
    @Published var errorMessage:  String?

    private var hasMore = true

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

            enum CodingKeys: String, CodingKey {
                case id
                case orderIndex = "order_index"
                case header, body, footer
                case imageUrl = "image_url"
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
        defer { isLoading = false }

        do {
            let rows: [TipRow] = try await supabase
                .from("tips")
                .select("id, title, banner_url, tip_pages(id, order_index, header, body, footer, image_url)")
                .order("title")
                .limit(20)
                .execute()
                .value

            tips = rows.map { Self.makeTip($0) }
            hasMore = rows.count == 20
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
                .select("id, title, banner_url, tip_pages(id, order_index, header, body, footer, image_url)")
                .order("title")
                .range(from: tips.count, to: tips.count + 9)
                .execute()
                .value

            tips.append(contentsOf: rows.map { Self.makeTip($0) })
            hasMore = rows.count == 10
        } catch {
            print("TipsViewModel fetchMore error:", error)
        }
    }

    // MARK: - Helper

    private static func makeTip(_ row: TipRow) -> Tip {
        var tip = Tip(id: row.id, title: row.title, bannerURL: row.bannerUrl ?? "")
        tip.pages = (row.tipPages ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { p in
                TipPage(
                    id: p.id,
                    imageURL: p.imageUrl ?? "",
                    header: p.header ?? "",
                    body: p.body ?? "",
                    footer: p.footer
                )
            }
        return tip
    }
}
