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

              let routes = snap?.documents.compactMap(Route.init(from:)) ?? []
              completion(.success(routes))
          }
    }
    
    func fetchStops(for routeID: String,
                    completion: @escaping (Result<[Stop],Error>) -> Void) {

        db.collection("routes")
          .document(routeID)
          .collection("stops")
          .order(by: "orderIndex")
          .getDocuments { snap, err in
              if let err = err { return completion(.failure(err)) }
              let stops = snap?.documents.compactMap { doc -> Stop? in
                  let d = doc.data()
                  guard
                      let name  = d["name"]        as? String,
                      let geo   = d["coordinates"] as? GeoPoint,
                      let idx   = d["orderIndex"]  as? Int,
                      let time  = d["timeSpent"]   as? Int
                  else { return nil }

                  let url = (d["photoURL"] as? String).flatMap(URL.init)
                  let notes = d["notes"] as? String
                  
                  return Stop(id: doc.documentID,
                              name: name,
                              coordinates: geo,
                              orderIndex: idx,
                              timeSpent: time,
                              photoURL: url,
                              notes: notes)
              } ?? []
              completion(.success(stops))
          }
    }

    
}
extension Route {
    init?(from doc: QueryDocumentSnapshot) {
        let d = doc.data()

        guard let title  = d["title"]      as? String,
              let author = d["authorUID"]  as? String else { return nil }

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

