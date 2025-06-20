import Foundation

// ───────── TipPage
struct TipPage: Identifiable {
    let id:       String          // documentID
    let imageURL: String
    let header:   String
    let body:     String
    let footer:   String?
}

// ───────── Tip
struct Tip: Identifiable, Equatable {
    let id: String
       let title: String
       let bannerURL: String
       var pages: [TipPage] = []

       static func == (lhs: Tip, rhs: Tip) -> Bool {
           lhs.id == rhs.id
       }
}
