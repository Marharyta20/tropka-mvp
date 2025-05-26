// SavedRoutesStore.swift
import FirebaseAuth
import FirebaseFirestore
import Combine

final class SavedRoutesStore: ObservableObject {
    @Published private(set) var savedIDs: Set<String> = []

    static let shared = SavedRoutesStore()   // один экземпляр
    private var listener: ListenerRegistration?

    private init() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("savedRoutes")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.savedIDs = Set(docs.map { $0.documentID })
            }
    }
}
