import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthService {
    static let shared = AuthService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, fullName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user, let self = self else { return }
            
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "fullName": fullName, // <--- Было "name", стало "fullName"
                "username": "user\(Int.random(in: 1000...9999))", // Можно добавить дефолтный юзернейм
                "role": "user",
                "createdAt": FieldValue.serverTimestamp(),
                "city": ""
            ]
            
            self.db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        try? Auth.auth().signOut()
    }
}
