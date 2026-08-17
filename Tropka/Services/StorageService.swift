import Foundation
import Storage

// MARK: - Buckets

/// Buckets that exist in the Supabase project. Names must match exactly — this
/// used to hardcode a non-existent "tropka-media", so every upload failed
/// silently and all buckets stayed empty.
enum StorageBucket: String {
    case routes   // route cover images
    case avatars  // profile photos
    case places   // place photos
    case tips     // tip artwork
}

// MARK: - StorageService (Supabase Storage)

final class StorageService {
    static let shared = StorageService()
    private init() {}

    // MARK: Generic operations

    /// Uploads data to the given bucket and returns its public URL.
    @discardableResult
    func uploadImage(_ data: Data,
                     to bucket: StorageBucket,
                     path: String) async throws -> URL {
        _ = try await supabase.storage
            .from(bucket.rawValue)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return try supabase.storage.from(bucket.rawValue).getPublicURL(path: path)
    }

    /// Public URL for a file that already exists — no upload.
    func publicURL(in bucket: StorageBucket, path: String) throws -> URL {
        try supabase.storage.from(bucket.rawValue).getPublicURL(path: path)
    }

    // MARK: Named use cases

    /// Route cover image.
    func uploadRouteThumbnail(_ data: Data) async throws -> URL {
        try await uploadImage(data,
                              to: .routes,
                              path: "thumbnails/\(UUID().uuidString).jpg")
    }

    /// User avatar.
    ///
    /// The path must start with a folder equal to `auth.uid()` — the storage
    /// policy "Auth upload avatars" checks `(storage.foldername(name))[1]`.
    /// The path is built here rather than at the call site, so nobody can pass
    /// an arbitrary one and get an opaque 403.
    func uploadAvatar(_ data: Data) async throws -> URL {
        guard let uid = supabase.auth.currentUser?.id.uuidString else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await uploadImage(data,
                                     to: .avatars,
                                     path: "\(uid)/\(UUID().uuidString).jpg")
    }
}
