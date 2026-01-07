import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

// MARK: – DTO
struct SavedRoute: Identifiable {
    let route: TourRoute
    let savedAt: Date?
    let isPurchased: Bool
    var id: String { route.id }
}

@MainActor
class ProfileViewModel: ObservableObject {
    
    // user
    @Published var displayName = "Loading..."
    @Published var city        = ""
    @Published var registrationDate: Date?
    @Published var handle      = ""           // unique @username / nick
    
    // saved / purchased routes
    @Published var routes: [SavedRoute] = []
    
    // error banner
    @Published var errorMessage: String?
    
    private let db   = Firestore.firestore()
    private let auth = Auth.auth()
    
    //saved
    private var cancellable: AnyCancellable?
    
    //wishlist
    @Published var wishlist: [SavedRoute] = []
    private var wishCanc: AnyCancellable?
    private let wishlistSvc = WishlistService()
    
    //reviews
    @Published var myReviews: [UserReview] = []
    private let reviewSvc = ReviewService()
    
    init() {
        fetchUserProfile()
        fetchSavedRoutes()
        cancellable = SavedRoutesStore.shared.$savedIDs
            .sink { [weak self] _ in self?.fetchSavedRoutes() }
        wishCanc = WishlistStore.shared.$wishIDs
            .sink { [weak self] ids in
                Task { await self?.loadWishlist(ids: ids) }
            }
        loadReviews()
    }
    
    // MARK: – Profile
    private func fetchUserProfile() {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "Unable to get user UID"
            return
        }
        db.collection("users").document(uid).getDocument { [weak self] snap, err in
            DispatchQueue.main.async {
                if let err = err { self?.errorMessage = err.localizedDescription; return }
                guard let data = snap?.data() else { self?.errorMessage = "Profile not found"; return }
                
                self?.displayName = data["fullName"] as? String ?? "Unknown User"
                self?.handle      = data["username"]  as? String ?? "user"
                self?.city        = data["city"]     as? String ?? ""
                if let ts = data["registrationDate"] as? Timestamp {
                    self?.registrationDate = ts.dateValue()
                }
            }
        }
    }
    
    // MARK: – Saved / purchased routes
    /// Reads `users/{uid}/savedRoutes` (doc IDs = route IDs) and loads corresponding docs from `routes` collection
    private func fetchSavedRoutes() {
        guard let uid = auth.currentUser?.uid else { return }
        nonisolated(unsafe) let db = self.db
        
        db.collection("users")
            .document(uid)
            .collection("savedRoutes")
            .getDocuments { [weak self] snap, err in
                
                if let err = err {
                    DispatchQueue.main.async { self?.errorMessage = err.localizedDescription }
                    return
                }
                
                // routeId → (savedAt, isPurchased)
                var meta: [String: (Date?, Bool)] = [:]
                snap?.documents.forEach { doc in
                    let data = doc.data()
                    let date = (data["savedAt"] as? Timestamp)?.dateValue()
                    let paid = data["isPurchased"] as? Bool ?? false
                    meta[doc.documentID] = (date, paid)
                }
                
                let ids = Array(meta.keys)
                guard !ids.isEmpty else {
                    DispatchQueue.main.async { self?.routes = [] }
                    return
                }
                
                // Firestore `in` accepts ≤10 IDs
                let chunks = stride(from: 0, to: ids.count, by: 10)
                    .map { Array(ids[$0..<min($0 + 10, ids.count)]) }
                
                var collected: [SavedRoute] = []
                let group = DispatchGroup()
                
                for chunk in chunks {
                    group.enter()
                    db.collection("routes")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments { qs, _ in
                            qs?.documents.forEach { doc in
                                let d = doc.data()
                                
                                let route = TourRoute(
                                    id:          doc.documentID,
                                    title:       d["title"]        as? String ?? "Untitled",
                                    authorUID:   d["authorUID"]    as? String ?? "",
                                    rating:      d["rating"]       as? Double ?? 0,
                                    reviewCount: d["reviewCount"]  as? Int ?? 0,
                                    duration:    d["duration"]     as? Double ?? 0,
                                    tags:        (d["tags"] as? [Any])?.compactMap { $0 as? String } ?? [],
                                    price:       d["price"]        as? Double,
                                    thumbnailURL:(d["thumbnailURL"] as? String).flatMap(URL.init),
                                    stopsCount:  d["stopsCount"]   as? Int ?? 0
                                )
                                
                                collected.append(
                                    SavedRoute(
                                        route:       route,
                                        savedAt:     meta[doc.documentID]?.0,
                                        isPurchased: meta[doc.documentID]?.1 ?? false
                                    )
                                )
                            }
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) { [weak self] in
                    Task { @MainActor in
                        self?.routes = collected.sorted {
                            ($0.savedAt ?? .distantPast) > ($1.savedAt ?? .distantPast)
                        }
                    }
                }
            }
    }
    
    func unsave(routeID: String) async {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "Unable to get user UID"
            return
        }
        
        // optimistic UI update
        if let idx = routes.firstIndex(where: { $0.id == routeID }) {
            _ = withAnimation { routes.remove(at: idx) }
        }
        
        do {
            try await db.collection("users")
                .document(uid)
                .collection("savedRoutes")
                .document(routeID)
                .delete()
        } catch {
            fetchSavedRoutes()
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func loadWishlist(ids: Set<String>) async {
        guard !ids.isEmpty else { wishlist = []; return }
        
        let idArray = Array(ids)
        let chunks = stride(from: 0, to: idArray.count, by: 10)
            .map { Array(idArray[$0..<min($0+10, idArray.count)]) }
        
        var collected: [SavedRoute] = []
        for chunk in chunks {
            if let qs = try? await db.collection("routes")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments() {
                
                for doc in qs.documents {
                    let d = doc.data()
                    let route = TourRoute(
                        id:          doc.documentID,
                        title:       d["title"]        as? String ?? "Untitled",
                        authorUID:   d["authorUID"]    as? String ?? "",
                        rating:      d["rating"]       as? Double ?? 0,
                        reviewCount: d["reviewCount"]  as? Int ?? 0,
                        duration:    d["duration"]     as? Double ?? 0,
                        tags:        (d["tags"] as? [Any])?.compactMap { $0 as? String } ?? [],
                        price:       d["price"]        as? Double,
                        thumbnailURL:(d["thumbnailURL"] as? String).flatMap(URL.init),
                        stopsCount:  d["stopsCount"]   as? Int ?? 0
                    )
                    collected.append(
                        SavedRoute(route: route,
                                   savedAt: nil,
                                   isPurchased: false)
                    )
                }
            }
        }
        wishlist = collected.sorted { $0.route.title < $1.route.title }
    }
    
    func unwish(routeID: String) {
        Task { try? await wishlistSvc.set(false, routeID: routeID) }
    }
    
    func loadReviews() {
        Task { @MainActor in
            do   { myReviews = try await reviewSvc.fetchMyReviews() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    @MainActor
    func update(review: UserReview) async {
        myReviews = myReviews.map { $0.routeID == review.routeID ? review : $0 }
        _ = try? await reviewSvc.upsert(review: review)
    }

    @MainActor
    func delete(review: UserReview) async {
        try? await reviewSvc.delete(review: review)
        myReviews.removeAll { $0.routeID == review.routeID }
    }
    
    @MainActor
    func create(review: UserReview) async {
        do {
            try await reviewSvc.create(review: review)
            loadReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
