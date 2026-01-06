import Foundation
import FirebaseFirestore
import FirebaseAuth

struct RouteEditorService {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: Create
    /// Creates a new route document under `routes` and writes its stops under `routes/{routeID}/stops`.
    /// Returns the created route ID.
    func createRoute(title: String, tags: [String], price: Double?, thumbnailURL: URL?, stops: [Stop]) async throws -> String {
        guard let uid = auth.currentUser?.uid else { throw URLError(.userAuthenticationRequired) }

        let routeRef = db.collection("routes").document()
        let createdAt = Timestamp(date: Date())

        // Derive metadata
        let stopsCount = stops.count
        let totalMinutes = stops.reduce(0) { $0 + max(0, $1.timeSpent) }
        let durationHours = Double(totalMinutes) / 60.0

        // Base route data
        var routeData: [String: Any] = [
            "title": title,
            "authorUID": uid,
            "createdAt": createdAt,
            "rating": 0.0,
            "reviewCount": 0,
            "duration": durationHours,
            "tags": tags,
            "stopsCount": stopsCount
        ]
        if let price = price { routeData["price"] = price }
        if let thumb = thumbnailURL?.absoluteString { routeData["thumbnailURL"] = thumb }

        try await db.runTransaction { txn, _ in
            txn.setData(routeData, forDocument: routeRef)
            return ()
        }

        try await writeStops(routeID: routeRef.documentID, stops: stops)
        return routeRef.documentID
    }

    // MARK: Update
    /// Updates the route document and replaces its stops with the given array.
    func updateRoute(routeID: String, title: String, stops: [Stop], tags: [String], price: Double?, thumbnailURL: URL?) async throws {
        guard let uid = auth.currentUser?.uid else { throw URLError(.userAuthenticationRequired) }
        let routeRef = db.collection("routes").document(routeID)

        // Derive metadata
        let stopsCount = stops.count
        let totalMinutes = stops.reduce(0) { $0 + max(0, $1.timeSpent) }
        let durationHours = Double(totalMinutes) / 60.0

        var update: [String: Any] = [
            "title": title,
            "authorUID": uid,
            "duration": durationHours,
            "stopsCount": stopsCount,
            "tags": tags
        ]
        if let price = price { update["price"] = price }
        if let thumb = thumbnailURL?.absoluteString { update["thumbnailURL"] = thumb }

        try await routeRef.setData(update, merge: true)
        try await replaceStops(routeID: routeID, stops: stops)
    }

    // MARK: Fetch (for Edit)
    /// Fetches route title and its stops ordered by orderIndex.
    func fetchRoute(routeID: String) async throws -> (title: String, stops: [Stop]) {
        let routeRef = db.collection("routes").document(routeID)
        let routeSnap = try await routeRef.getDocument()
        guard let data = routeSnap.data() else { throw NSError(domain: "RouteEditorService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Route not found"]) }
        let title = data["title"] as? String ?? ""

        let stopsQS = try await routeRef.collection("stops").order(by: "orderIndex").getDocuments()
        var arr: [Stop] = []
        for doc in stopsQS.documents {
            let d = doc.data()
            guard
                let name = d["name"] as? String,
                let geo = d["coordinates"] as? GeoPoint,
                let idx = d["orderIndex"] as? Int,
                let time = d["timeSpent"] as? Int
            else { continue }
            let url = (d["photoURL"] as? String).flatMap(URL.init)
            let notes = d["notes"] as? String
            arr.append(Stop(id: doc.documentID, name: name, coordinates: geo, orderIndex: idx, timeSpent: time, photoURL: url, notes: notes))
        }
        return (title, arr)
    }

    // MARK: Helpers
    private func writeStops(routeID: String, stops: [Stop]) async throws {
        let stopsRef = db.collection("routes").document(routeID).collection("stops")
        let batch = db.batch()
        for s in stops {
            let doc = stopsRef.document(s.id)
            batch.setData(stopPayload(s), forDocument: doc)
        }
        try await batch.commit()
    }

    private func replaceStops(routeID: String, stops: [Stop]) async throws {
        let stopsRef = db.collection("routes").document(routeID).collection("stops")
        // Fetch existing
        let existing = try await stopsRef.getDocuments()
        let batch = db.batch()
        for doc in existing.documents { batch.deleteDocument(doc.reference) }
        for s in stops { batch.setData(stopPayload(s), forDocument: stopsRef.document(s.id)) }
        try await batch.commit()
    }

    private func stopPayload(_ s: Stop) -> [String: Any] {
        var dict: [String: Any] = [
            "name": s.name,
            "coordinates": s.coordinates,
            "orderIndex": s.orderIndex,
            "timeSpent": s.timeSpent
        ]
        if let url = s.photoURL?.absoluteString { dict["photoURL"] = url }
        if let notes = s.notes { dict["notes"] = notes }
        return dict
    }
}
