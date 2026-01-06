import Foundation
import FirebaseFirestore

/// View-model that loads the public “Explore” list of routes
/// and exposes them to SwiftUI.
final class ExploreViewModel: ObservableObject {
    
    // MARK: - Published state
    
    @Published var routes:    [TourRoute] = []
    @Published var isLoading: Bool    = false
    @Published var errorMsg:  String?
    
    // MARK: - Private
    
    private let db = Firestore.firestore()
    
    // MARK: - Public API
    
    /// Call from `.onAppear {}` in the view.
    func loadRoutes() {
        isLoading = true
        errorMsg  = nil
        
        db.collection("routes")
            .order(by: "rating", descending: true)          // ← any sort you like
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let err = err {
                        self.errorMsg = err.localizedDescription
                        return
                    }
                    
                    self.routes = snap?.documents.compactMap { doc -> TourRoute? in
                        let d = doc.data()
                        
                        // — required ﬁelds
                        guard
                            let title  = d["title"]      as? String,
                            let author = d["authorUID"]  as? String
                        else { return nil }
                        
                        // — optional convert
                        let thumbURL = (d["thumbnailURL"] as? String).flatMap(URL.init)
                        
                        return TourRoute(
                            id:           doc.documentID,
                            title:        title,
                            authorUID:    author,
                            rating:       d["rating"]       as? Double ?? 0,
                            reviewCount:  d["reviewCount"] as? Int    ?? 0,
                            duration:     d["duration"]     as? Double ?? 0,
                            tags:         d["tags"]         as? [String] ?? [],
                            price:        d["price"]        as? Double,     // nil → free
                            thumbnailURL: thumbURL,
                            stopsCount: d["stopsCount"] as? Int    ?? 0
                        )
                    } ?? []
                }
            }
    }
}
