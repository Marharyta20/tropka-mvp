import Foundation

struct TipPage: Identifiable {
    let id: String
    let imageURL: String
    let header: String
    let body: String
    let footer: String?
}

struct Tip: Identifiable {
    let id: String
    let title: String
    let bannerURL: String
    var pages: [TipPage] = []
}
