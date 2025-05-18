import SwiftUI
import Firebase
import FirebaseFirestore

struct TestView: View {
  var body: some View {
    Text("Firestore test")
      .onAppear {
        let db = Firestore.firestore()
        db.collection("routes").getDocuments { snap, err in
          print("tags →", snap?.documents.map { $0.documentID } ?? [], err ?? "")
        }
      }
  }
}
