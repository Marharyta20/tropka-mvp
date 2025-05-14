import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth      // ← don’t forget this!

final class ProfileViewModel: ObservableObject {
  @Published var displayName = ""
  @Published var city        = ""

  private let db = Firestore.firestore()

  func fetchProfile() {
    print("🔍 fetchProfile called")
    guard let uid = Auth.auth().currentUser?.uid else {
      print("⚠️ No logged-in user; Auth.auth().currentUser is nil")
      return
    }
    print("ℹ️ Using uid: \(uid)")

    db.collection("users")
      .document(uid)
      .getDocument { [weak self] snap, error in
        if let error = error {
          print("❌ Firestore getDocument error:", error)
          return
        }
        guard let data = snap?.data() else {
          print("⚠️ Document exists? \(snap?.exists ?? false). Data nil.")
          return
        }
        print("✅ Fetched data:", data)

        DispatchQueue.main.async {
          self?.displayName = data["username"] as? String ?? "<no-name>"
          self?.city        = data["city"]     as? String ?? "<no-city>"
        }
      }
  }
}
