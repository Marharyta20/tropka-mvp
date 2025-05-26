import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var city        = ""
    @Published var error: String?
    @Published var isBusy = false          // для спиннера

    private let db   = Firestore.firestore()
    private let auth = Auth.auth()

    init() { Task { await load() } }

    // MARK: load current values
    func load() async {
        guard let uid = auth.currentUser?.uid else { return }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            guard let data = snap.data() else { return }
            displayName = data["username"] as? String ?? ""
            city        = data["city"]     as? String ?? ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: save name + city
    func save() async {
        guard let uid = auth.currentUser?.uid else { return }
        isBusy = true
        do {
            try await db.collection("users").document(uid).updateData([
                "username": displayName,
                "city":     city
            ])
            isBusy = false
        } catch {
            isBusy = false
            self.error = error.localizedDescription
        }
    }

    // MARK: sign out
    func signOut() {
        try? auth.signOut()
    }

    // MARK: delete account
    func deleteAccount() async {
        isBusy = true
        do {
            guard let user = auth.currentUser else { return }
            // удаляем Firestore-док
            try await db.collection("users").document(user.uid).delete()
            // удаляем auth-пользователя
            try await user.delete()
            isBusy = false
        } catch {
            isBusy = false
            self.error = error.localizedDescription
        }
    }
}
