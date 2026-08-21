import SwiftUI

/// A place's Google rating, shown as what it actually is.
///
/// The score comes from the Google import, and it is not Tropka's own rating —
/// so it says so, and the whole thing opens the place's Google listing. That is
/// both what makes it honest (Google's terms ask for attribution) and the only
/// way to reach the reviews behind the number, which cannot be read in Tropka.
/// The link is already in `source_url` for effectively the whole catalogue, so
/// opening it costs nothing: no key, no quota, no billing.
///
/// The review count is deliberately not shown. It was a number with nowhere to
/// go, and now that the score itself is the way through to Google, it added
/// nothing but width.
///
/// Falls back to a plain, non-tappable label when a place has no `source_url`.
struct GoogleRating: View {
    let rating: Double
    let sourceURL: URL?

    @ViewBuilder
    var body: some View {
        if rating > 0 {
            if let sourceURL {
                Link(destination: sourceURL) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
    }

    /// The star and the score are inside the link too — tapping the number the
    /// user is reading is what they will try first.
    private var label: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundColor(.yellow)

            Text(String(format: "%.1f", rating))
                .font(.caption)
                .foregroundColor(.primary)

            Text("on Google")
                .font(.caption2)
                .foregroundColor(.secondary)

            if sourceURL != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        GoogleRating(rating: 4.6,
                     sourceURL: URL(string: "https://www.google.com/maps/place/?q=place_id:ChIJSS5pkozMHkcRwi0fMeV66cI"))
        GoogleRating(rating: 4.6, sourceURL: nil)
        GoogleRating(rating: 0, sourceURL: nil)
    }
    .padding()
}
