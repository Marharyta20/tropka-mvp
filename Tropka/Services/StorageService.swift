import Foundation
import FirebaseStorage

final class StorageService {
  static let shared = StorageService()
  private let storageRef = Storage.storage().reference()

  /// Uploads raw image/video data to `path` and returns the public URL
  func uploadImage(_ data: Data, path: String) async throws -> URL {
    let ref = storageRef.child(path)
    _ = try await ref.putDataAsync(data)
    return try await ref.downloadURL()
  }

  /// Fetches the download URL for a given storage path
  func downloadURL(for path: String) async throws -> URL {
    let ref = storageRef.child(path)
    return try await ref.downloadURL()
  }
}
