import SDWebImageSwiftUI
import SwiftUI

// MARK: - Featured route

/// The card at the top of Explore. It exists to give the page a sense of scale:
/// a wall of equal-sized cards reads as a list, not as a home screen.
///
/// Shorter than it was. It used to be 230pt and the only thing above the fold,
/// so the home screen was one photograph — now the place near you sits under it
/// and both have to be visible without scrolling for either to do its job.
struct FeaturedRouteCard: View {
    let route: TourRoute

    private static let height: CGFloat = 186

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
            .frame(height: Self.height)
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
                            AvatarView(stored: route.authorAvatar, size: 20, userID: route.authorUID)
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
        .frame(height: Self.height)
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

// MARK: - Place near you

/// The second card: a place worth a detour, picked from what is actually around
/// the user right now.
///
/// Wider and shorter than the route above it, and carrying its distance, because
/// two identical hero cards stacked would read as a carousel somebody forgot to
/// make swipeable. This one answers a different question — not "what shall I do
/// today" but "what is round the corner".
struct NearbyPlaceCard: View {
    let place: PlaceDetails
    /// nil when we have no fix; the card then drops the distance rather than
    /// inventing one.
    let metresAway: Double?

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let url = place.photoURL {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 124, height: 124)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: place.category.icon)
                        .font(.caption2)
                        .foregroundColor(Color(place.category.color))
                    Text(place.category.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(place.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    if place.rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", place.rating))
                        }
                    }
                    if let metresAway {
                        Label(Self.walking(metresAway), systemImage: "figure.walk")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 124)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    /// Minutes, not metres, past the point where metres stop meaning anything.
    /// 80 metres a minute is an ordinary walking pace on city pavement.
    private static func walking(_ metres: Double) -> String {
        if metres < 300 { return "\(Int((metres / 50).rounded()) * 50) m" }
        let minutes = max(1, Int((metres / 80).rounded()))
        return "\(minutes) min walk"
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

// MARK: - All places

/// First tile in the category row, and deliberately not a category.
///
/// Browsing by category is the second thing people want; the first is to see
/// that there is a catalogue at all. This used to be reachable only through the
/// segmented control at the top of the screen, which is now gone.
struct AllPlacesTile: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                Spacer(minLength: 0)

                Text("All places")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(count > 0 ? "\(count) in the guide" : "The whole catalogue")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(12)
            .frame(width: 128, height: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tropkaBlue)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Result badge

/// Marks a search result as one kind of thing or the other.
///
/// The home screen searches routes and places at once now that there is no
/// segmented control saying which one you are in. Two headers would be enough
/// until somebody scrolls past one, so every row carries its own label.
struct ResultKindBadge: View {
    let isRoute: Bool

    var body: some View {
        Text(isRoute ? "Route" : "Place")
            .font(.caption2.bold())
            .foregroundColor(isRoute ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(isRoute ? Color.tropkaBlue : Color(.systemGray5))
            )
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
