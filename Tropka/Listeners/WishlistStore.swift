// WishlistStore.swift
import Combine
import FirebaseAuth
import FirebaseFirestore

final class WishlistStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    static let shared = WishlistStore()
    private var listener: ListenerRegistration?

    private init() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("wishlist")
            .addSnapshotListener { [weak self] snap, _ in
                let docs = snap?.documents ?? []
                self?.ids = Set(docs.map(\.documentID))
            }
    }
}
