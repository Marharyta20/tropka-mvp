class ProfileViewModel: ObservableObject {
  @Published var displayName = ""
  @Published var city        = ""
  @Published var photoURL    = URL(string: "")

  private var listener: ListenerRegistration?

  func bind(to uid: String) {
    listener = Firestore.firestore()
      .collection("users")
      .document(uid)
      .addSnapshotListener { [weak self] snap, error in
        guard let data = snap?.data(), error == nil else { return }
        self?.displayName = data["username"]   as? String ?? ""
        self?.city        = data["city"]       as? String ?? ""
        if let urlString = data["photoURL"]    as? String {
          self?.photoURL  = URL(string: urlString)
        }
      }
  }

  deinit { listener?.remove() }
}
