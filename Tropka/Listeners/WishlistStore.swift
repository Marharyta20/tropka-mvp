import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class WishlistStore {
    static let shared = WishlistStore()
    private init() { subscribe() }

    @Published private(set) var wishIDs: Set<String> = []

    private let db   = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authStateCancellable: AnyCancellable?

    private func subscribe() {
        authStateCancellable = Auth.auth().publisher(for: \.currentUser)
            .sink { [weak self] user in
                self?.listener?.remove()
                self?.wishIDs = []
                guard let uid = user?.uid else { return }
                self?.listen(toUID: uid)
            }
    }

    private func listen(toUID uid: String) {
        listener = db.collection("users")
            .document(uid)
            .collection("wishlist")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                let ids = docs.map(\.documentID)
                self?.wishIDs = Set(ids)
            }
    }

    deinit {
        listener?.remove()
        authStateCancellable?.cancel()
    }
}
