import SDWebImageSwiftUI
import SwiftUI

// MARK: - Featured route

/// The one big card at the top of Explore. It exists to give the page a sense of
/// scale: a wall of equal-sized cards reads as a list, not as a home screen.
struct FeaturedRouteCard: View {
    let route: TourRoute

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = route.thumbnailURL {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    LinearGradient(colors: [.blue.opacity(0.7), .indigo],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(route.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let author = route.authorName {
                        HStack(spacing: 5) {
                            AvatarView(stored: route.authorAvatar, size: 20)
                            Text(author)
                        }
                    }
                    Text("\(route.stopsCount) stops")
                    Text(route.duration.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            Text("Route of the day")
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(12)
        }
    }
}

// MARK: - Category tile

/// Doorway into the catalogue. The place count is the point: it tells the user
/// there is far more here than the handful of routes above.
struct CategoryTile: View {
    let category: PlaceCategory
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(Color(category.color))

                Spacer(minLength: 0)

                Text(category.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(count) places")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 128, height: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(category.color).opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
