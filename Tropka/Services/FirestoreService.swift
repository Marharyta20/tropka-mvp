import Foundation
import FirebaseFirestore

final class FirestoreService {
  static let shared = FirestoreService()
  private let db = Firestore.firestore()

  private init() {}

  /// Fetches all Route documents from the "routes" collection
  /// and decodes them into your Route model.
  func fetchRoutes(completion: @escaping ([Route]) -> Void) {
    db.collection("routes")
      .getDocuments { snapshot, error in
        if let error = error {
          print("⚠️ FirestoreService.fetchRoutes error:", error)
          completion([])
          return
        }
        let routes = snapshot?.documents.compactMap { doc in
          try? doc.data(as: Route.self)
        } ?? []
        completion(routes)
      }
  }

  /// Saves a Route under the current user's subcollection "users/{uid}/routes/{routeId}"
  /// Throws if the Route.id is missing or if Firestore write fails.
  func saveRoute(_ route: Route, forUID uid: String) async throws {
    guard let id = route.id else {
      throw NSError(
        domain: "FirestoreService",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Route ID is nil"]
      )
    }
    let ref = db
      .collection("users")
      .document(uid)
      .collection("routes")
      .document(id)
    try ref.setData(from: route)
  }

  // You can add more methods here, e.g.:
  // func fetchSavedRoutes(forUID uid: String, completion: @escaping ([Route]) -> Void) { … }
  // func deleteRoute(_ routeID: String, forUID uid: String) async throws { … }
}
