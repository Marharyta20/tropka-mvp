import Foundation
import FirebaseFirestore              // Firestore + GeoPoint
import Combine

// ─────────────────────────────────────────────────────────────
//  MARK: - View-model
// ─────────────────────────────────────────────────────────────

final class TourDetailsViewModel: ObservableObject {

    // MARK: - Published state
    @Published var stops:     [Stop] = []
    @Published var isLoading: Bool   = false

    // MARK: - Private
    private let db = Firestore.firestore()

    // MARK: - Public API
    /// Loads all stops for a given route (sub-collection `/stops`)
    func loadStops(for routeID: String) {
        isLoading = true

        db.collection("routes")
            .document(routeID)
            .collection("stops")
            .order(by: "orderIndex")                 // 🔑 important for correct order
            .getDocuments { [weak self] snap, err in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false

                    if let err = err {
                        print("❌ Failed to fetch stops:", err)
                        return
                    }

                    self.stops = snap?.documents.compactMap { doc -> Stop? in
                        let d = doc.data()

                        // mandatory fields
                        guard
                            let name       = d["name"]         as? String,
                            let geo        = d["coordinates"]  as? GeoPoint,
                            let order      = d["orderIndex"]   as? Int,
                            let timeSpent  = d["timeSpent"]    as? Int
                        else { return nil }

                        // optional
                        let photoURL = (d["photoURL"] as? String).flatMap(URL.init)

                        return Stop(id:          doc.documentID,
                                    name:        name,
                                    coordinate:  geo,
                                    order:       order,
                                    timeSpent:   timeSpent,
                                    photoURL:    photoURL)
                    } ?? []
                }
            }
    }
}
