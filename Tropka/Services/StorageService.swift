import Foundation
import Storage

// MARK: - StorageService (Supabase Storage)

final class StorageService {
    static let shared = StorageService()
    private init() {}

    private let bucket = "tropka-media"

    /// Uploads raw image data and returns the public URL.
    func uploadImage(_ data: Data, path: String) async throws -> URL {
        _ = try await supabase.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return try supabase.storage.from(bucket).getPublicURL(path: path)
    }

    /// Returns the public URL for an existing path without uploading.
    func publicURL(for path: String) throws -> URL {
        try supabase.storage.from(bucket).getPublicURL(path: path)
    }
}
