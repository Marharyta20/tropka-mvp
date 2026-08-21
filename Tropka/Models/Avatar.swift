import SwiftUI

// MARK: - Avatar

/// A preset avatar bundled with the app. Users pick from these rather than
/// uploading their own, so the whole set ships in the asset catalogue: instant
/// to render, works offline, no storage bill. The trade-off is that adding an
/// eighth one needs an app release.
struct Avatar: Identifiable, Equatable, Hashable {
    let id: String          // matches the asset name, e.g. "avatar-3"

    var assetName: String { id }

    /// What goes into `users.photo_url`.
    ///
    /// The column stays a URL column: a `preset://` scheme marks a bundled image,
    /// anything with http(s) is a real remote picture. That keeps the door open
    /// for user uploads later without a migration.
    var storedValue: String { "\(Avatar.scheme)://\(id)" }

    static let scheme = "preset"

    static let presets: [Avatar] = (1...7).map { Avatar(id: "avatar-\($0)") }

    /// Reads back whatever is stored in `users.photo_url`.
    static func preset(from stored: String?) -> Avatar? {
        guard let stored,
              stored.hasPrefix("\(scheme)://")
        else { return nil }
        let id = String(stored.dropFirst(scheme.count + 3))
        return presets.first { $0.id == id }
    }

    /// A remote picture, for the day uploads are allowed.
    static func remoteURL(from stored: String?) -> URL? {
        guard let stored,
              let url = URL(string: stored),
              url.scheme == "http" || url.scheme == "https"
        else { return nil }
        return url
    }
}

// MARK: - AvatarView

/// Renders whatever `users.photo_url` holds — a bundled preset, a remote image,
/// or the fallback placeholder — always as a circle.
struct AvatarView: View {
    let stored: String?
    var size: CGFloat = 72
    /// Whose picture this is. Pass it wherever an *author's* avatar is drawn
    /// from a cached list: when the author turns out to be the signed-in user,
    /// the live value wins over the embedded copy, which is otherwise a snapshot
    /// from whenever that list was fetched.
    var userID: String? = nil

    @ObservedObject private var preferences = UserPreferences.shared

    private var shown: String? {
        guard let userID, preferences.isMe(userID) else { return stored }
        return preferences.avatarValue ?? stored
    }

    var body: some View {
        Group {
            if let preset = Avatar.preset(from: shown) {
                Image(preset.assetName)
                    .resizable()
                    .scaledToFill()
            } else if let url = Avatar.remoteURL(from: shown) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image("profile-placeholder")
            .resizable()
            .scaledToFill()
    }
}
