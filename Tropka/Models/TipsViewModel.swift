import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class TipsViewModel: ObservableObject {
    @Published var tips: [Tip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadTips() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("tips").getDocuments()
            tips = try snapshot.documents.compactMap { doc in
                try doc.data(as: Tip.self)
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
