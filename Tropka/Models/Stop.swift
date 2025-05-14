import FirebaseFirestore

struct Stop: Identifiable {
    let id: String
    let name: String
    let coordinate: GeoPoint
    let order: Int
    let photoURL: URL?
}
