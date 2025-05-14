import FirebaseFirestore

final class TourDetailsViewModel: ObservableObject {
    @Published var stops: [Stop] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadStops(for routeId: String) {
        isLoading = true
        db.collection("routes")
          .document(routeId)
          .collection("stops")
          .order(by: "order")
          .getDocuments { [weak self] snap, err in
              DispatchQueue.main.async {
                  self?.isLoading = false
                  if let err = err { print("❌ stops error:", err); return }

                  self?.stops = snap?.documents.compactMap { doc in
                      let d = doc.data()
                      guard
                        let name  = d["name"]       as? String,
                        let geo   = d["coordinates"] as? GeoPoint,
                        let order = d["order"]      as? Int
                      else { return nil }

                      let photo = (d["photoURL"] as? String).flatMap(URL.init)
                      return Stop(id: doc.documentID,
                                  name: name,
                                  coordinate: geo,
                                  order: order,
                                  photoURL: photo)
                  } ?? []
              }
          }
    }
}
