import Foundation

// MARK: - AuthService (Supabase Auth)

final class AuthService {
    static let shared = AuthService()
    private init() {}

    var currentUserID: String? {
        supabase.auth.currentUser?.id.uuidString
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, fullName: String) async throws {
        let response = try await supabase.auth.signUp(email: email, password: password)
        let user = response.user

        // Email деликатно не хранится в public.users: он живёт в auth.users и
        // доступен клиенту как supabase.auth.currentUser?.email. Благодаря этому
        // таблица профилей может быть открыта на чтение всем залогиненным
        // (нужно, чтобы показывать автора отзыва) без утечки адресов.
        struct UserInsert: Encodable {
            let id: String
            let fullName: String
            let username: String
            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
            }
        }

        let profile = UserInsert(
            id: user.id.uuidString,
            fullName: fullName,
            username: "user\(Int.random(in: 1000...9999))"
        )
        try await supabase.from("users").upsert(profile).execute()
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}

