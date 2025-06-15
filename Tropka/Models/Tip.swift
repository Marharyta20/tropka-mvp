import Foundation
import FirebaseFirestoreSwift

struct TipPage: Identifiable, Codable {
    let id: String
    let imageURL: String
    let header: String
    let body: String
    let footer: String?
}

struct Tip: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let bannerURL: String
    let pages: [TipPage]
}
