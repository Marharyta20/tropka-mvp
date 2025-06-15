import Foundation
import FirebaseFirestore

@MainActor
final class TipsViewModel: ObservableObject {
    @Published var tips: [Tip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    /// Fetch all tips + their pages
    func loadTips() async {
        isLoading = true
        errorMessage = nil

        do {
            let topSnap = try await db.collection("tips").getDocuments()
            var loaded: [Tip] = []

            for doc in topSnap.documents {
                let data = doc.data()
                let tipID     = doc.documentID
                let title     = data["title"]     as? String ?? ""
                let bannerURL = data["bannerURL"] as? String ?? ""

                // Build initial Tip
                var tip = Tip(
                    id:        tipID,
                    title:     title,
                    bannerURL: bannerURL,
                    pages:     []
                )

                // Now load pages sub-collection
                let pagesSnap = try await db
                    .collection("tips")
                    .document(tipID)
                    .collection("pages")
                    .getDocuments()

                tip.pages = pagesSnap.documents.map { pdoc in
                    let pd = pdoc.data()
                    return TipPage(
                        id:       pdoc.documentID,
                        imageURL: pd["imageURL"] as? String ?? "",
                        header:   pd["header"]   as? String ?? "",
                        body:     pd["body"]     as? String ?? "",
                        footer:   pd["footer"]   as? String
                    )
                }

                loaded.append(tip)
            }

            tips = loaded

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
