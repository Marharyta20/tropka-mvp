import Foundation
import FirebaseFirestore

struct Route: Identifiable, Codable {
  @DocumentID var id: String?
  let title: String
  let author: String
  let rating: Double
  let reviewCount: Int
  let duration: Double   // in hours
  let stops: [GeoPoint]
  let tags: [String]
  let price: Double?     // nil for free
  let thumbnailURL: URL?
  var isFree: Bool { price == nil }
}
