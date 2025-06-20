import Foundation
import FirebaseFirestore

@MainActor
final class TipsViewModel: ObservableObject {

    // UI-binding
    @Published var tips:          [Tip] = []
    @Published var isLoading        = false
    @Published var isLoadingMore    = false
    @Published var errorMessage: String?

    private let db      = Firestore.firestore()
    private var lastDoc: DocumentSnapshot?          // cursor

    // MARK: first page
    func reload() async {
        guard !isLoading else { return }
        isLoading  = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snap = try await db.collection("tips")
                                   .order(by: "title")        // индекс!
                                   .limit(to: 10)
                                   .getDocuments()

            tips     = try await parse(snapshot: snap)
            lastDoc  = snap.documents.last

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: next page
    func fetchMore() async {
        guard !isLoadingMore, let last = lastDoc else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let snap = try await db.collection("tips")
                                   .order(by: "title")
                                   .start(afterDocument: last)
                                   .limit(to: 10)
                                   .getDocuments()

            let more = try await parse(snapshot: snap)
            tips.append(contentsOf: more)
            lastDoc = snap.documents.last

        } catch {
            print("🔥 Pagination error:", error)
        }
    }

    // MARK: helper
    private func parse(snapshot: QuerySnapshot) async throws -> [Tip] {
        var result: [Tip] = []

        for doc in snapshot.documents {
            let data       = doc.data()
            let tipID      = doc.documentID
            let title      = data["title"]     as? String ?? ""
            let bannerURL  = data["bannerURL"] as? String ?? ""

            var tip = Tip(id: tipID, title: title, bannerURL: bannerURL)

            // load pages
            let pagesSnap = try await db.collection("tips")
                                        .document(tipID)
                                        .collection("pages")
                                        .getDocuments()

            tip.pages = pagesSnap.documents.map { p in
                let pd = p.data()
                return TipPage(id: p.documentID,
                               imageURL: pd["imageURL"] as? String ?? "",
                               header:   pd["header"]   as? String ?? "",
                               body:     pd["body"]     as? String ?? "",
                               footer:   pd["footer"]   as? String)
            }
            result.append(tip)
        }
        return result
    }
}
