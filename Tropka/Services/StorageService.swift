import Foundation
import Storage

// MARK: - Buckets

/// Бакеты, заведённые в проекте Supabase. Имена должны совпадать с ними точно —
/// раньше здесь был захардкожен несуществующий "tropka-media", и загрузка
/// молча падала на каждой попытке.
enum StorageBucket: String {
    case routes   // обложки маршрутов
    case avatars  // фото профиля
    case places   // фото мест
    case tips     // картинки для советов
}

// MARK: - StorageService (Supabase Storage)

final class StorageService {
    static let shared = StorageService()
    private init() {}

    // MARK: Универсальные операции

    /// Загружает данные в указанный бакет и возвращает публичную ссылку.
    @discardableResult
    func uploadImage(_ data: Data,
                     to bucket: StorageBucket,
                     path: String) async throws -> URL {
        _ = try await supabase.storage
            .from(bucket.rawValue)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return try supabase.storage.from(bucket.rawValue).getPublicURL(path: path)
    }

    /// Публичная ссылка на уже существующий файл — без загрузки.
    func publicURL(in bucket: StorageBucket, path: String) throws -> URL {
        try supabase.storage.from(bucket.rawValue).getPublicURL(path: path)
    }

    // MARK: Типовые сценарии

    /// Обложка маршрута.
    func uploadRouteThumbnail(_ data: Data) async throws -> URL {
        try await uploadImage(data,
                              to: .routes,
                              path: "thumbnails/\(UUID().uuidString).jpg")
    }

    /// Аватар пользователя.
    ///
    /// Путь обязан начинаться с папки, равной auth.uid() — этого требует политика
    /// хранилища "Auth upload avatars". Поэтому формируем его здесь, а не на
    /// стороне вызова: иначе рано или поздно кто-то передаст произвольный путь
    /// и получит невнятный 403.
    func uploadAvatar(_ data: Data) async throws -> URL {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await uploadImage(data,
                                     to: .avatars,
                                     path: "\(uid)/\(UUID().uuidString).jpg")
    }
}
