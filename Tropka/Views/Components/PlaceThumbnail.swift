import SDWebImageSwiftUI
import SwiftUI

/// What a place looks like when there is no photo — or, more often, when the photo
/// link is dead. A flat grey rectangle reads as a bug; a tinted card with the
/// category glyph reads as a choice, and it also tells the user something true
/// about the place.
struct CategoryPlaceholder: View {
    let category: PlaceCategory

    var body: some View {
        GeometryReader { geometry in
            let tint = Color(category.color)
            let side = min(geometry.size.width, geometry.size.height)

            LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.9)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.system(size: max(13, side * 0.34), weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                )
        }
    }
}

/// The single way a place photo is drawn anywhere in the app: real photo when it
/// loads, category card when it doesn't. SDWebImage keeps showing the placeholder
/// on failure, so a dead link falls back on its own.
struct PlaceThumbnail: View {
    let url: URL?
    var category: PlaceCategory = .other
    /// Cap the decoded size for small cards so a full-resolution photo doesn't
    /// get pulled into memory for a 52pt thumbnail.
    var thumbnailPixelSize: CGSize?

    var body: some View {
        if let url {
            if let thumbnailPixelSize {
                WebImage(url: url, context: [.imageThumbnailPixelSize: thumbnailPixelSize]) {
                    $0.resizable().scaledToFill()
                } placeholder: {
                    CategoryPlaceholder(category: category)
                }
            } else {
                WebImage(url: url) {
                    $0.resizable().scaledToFill()
                } placeholder: {
                    CategoryPlaceholder(category: category)
                }
            }
        } else {
            CategoryPlaceholder(category: category)
        }
    }
}
