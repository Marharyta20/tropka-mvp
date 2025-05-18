import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db    = Firestore.firestore()

    /// Загружаем public-маршруты (первые 50, отсортированы по createdAt)
    func fetchExploreRoutes(
        completion: @escaping (Result<[Route], Error>) -> Void
    ) {
        db.collection("routes")
          .order(by: "createdAt", descending: true)
          .limit(to: 50)
          .getDocuments { snap, err in

              if let err = err {
                  completion(.failure(err)); return
              }

              // ↘︎ вся «магия» парсинга в одной строке
              let routes = snap?.documents.compactMap(Route.init(from:)) ?? []
              completion(.success(routes))
          }
    }
}
extension Route {
    /// Удобный и *единственный* парсер: делает всю работу и не оставляет warning-ов
    init?(from doc: QueryDocumentSnapshot) {
        let d = doc.data()

        // обязательные поля
        guard let title  = d["title"]      as? String,
              let author = d["authorUID"]  as? String else { return nil }

        // всё остальное – опционально
        self.init(
            id:           doc.documentID,
            title:        title,
            authorUID:    author,
            rating:       d["rating"]       as? Double ?? 0,
            reviewCount:  d["reviewCount"]  as? Int    ?? 0,
            duration:     d["duration"]     as? Double ?? 0,
            tags:         d["tags"]         as? [String] ?? [],
            price:        d["price"]        as? Double,          // nil → free
            thumbnailURL: (d["thumbnailURL"] as? String).flatMap(URL.init),
            stopsCount:   d["stopsCount"]   as? Int ?? 0
        )
    }
}

