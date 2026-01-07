import Foundation
import FirebaseFirestore
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}

    // 1. Список маршрутов
    func fetchRoutes() async throws -> [TourRoute] {
        // Теперь можно раскомментировать, если у всех доков есть дата!
        let snapshot = try await db.collection("routes")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                if let route = TourRoute(from: doc) {
                    return route
                } else {
                    print("❌ Не удалось преобразовать документ: \(doc.documentID)")
                    print("   Данные: \(doc.data())")
                    return nil
                }
            }
        }
    
    // 2. Остановки (Метод async, без completion handler!)
    func fetchStops(for routeID: String) async throws -> [Stop] {
        let snapshot = try await db.collection("routes")
            .document(routeID)
            .collection("stops")
            .order(by: "orderIndex")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> Stop? in
            let d = doc.data()
            
            guard
                let name = d["name"] as? String,
                let geo = d["coordinates"] as? GeoPoint,
                let idx = d["orderIndex"] as? Int
            else { return nil }
            
            let time = d["timeSpent"] as? Int ?? 0
            let url = (d["photoURL"] as? String).flatMap(URL.init)
            let notes = d["notes"] as? String
            
            return Stop(
                id: doc.documentID,
                name: name,
                coordinates: geo,
                orderIndex: idx,
                timeSpent: time,
                photoURL: url,
                notes: notes
            )
        }
    }
}

// Расширение для TourRoute
extension TourRoute {
    init?(from doc: QueryDocumentSnapshot) {
        let d = doc.data()
        
        // Проверяем только title, остальное пытаемся спасти
        guard let title = d["title"] as? String else {
            print("⚠️ В документе \(doc.documentID) нет title")
            return nil
        }

        // Если автора нет, подставляем заглушку, чтобы маршрут не исчез
        let author = d["authorUID"] as? String ?? "Unknown Author"

        self.init(
            id: doc.documentID,
            title: title,
            authorUID: author,
            rating: d["rating"] as? Double ?? 0,
            reviewCount: d["reviewCount"] as? Int ?? 0,
            duration: d["duration"] as? Double ?? 0,
            tags: d["tags"] as? [String] ?? [],
            price: d["price"] as? Double, // Если в модели price опциональный (Double?)
            thumbnailURL: (d["thumbnailURL"] as? String).flatMap(URL.init),
            stopsCount: d["stopsCount"] as? Int ?? 0
        )
    }
}
