import SwiftUI

/// The one place the app admits something went wrong.
///
/// Six view models used to catch an error, store it in a property, and no view
/// ever read that property. The result was that failure and emptiness looked
/// identical: no network meant a map of Warsaw with no pins, a route that said
/// "No stops added yet", and a signed-in profile that looked like a brand-new
/// account. The rule that comes with this view — if a `catch` assigns to a
/// property, some view reads it.
struct ErrorBlock: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 26))
                .foregroundColor(.secondary)

            Text("Couldn't load this")
                .font(.subheadline.bold())

            Text(ErrorText.friendly(message))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let retry {
                Button("Try again", action: retry)
                    .font(.subheadline.bold())
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

/// One line, for screens that already have something on them. The map keeps its
/// basemap when a fetch fails, so a full-screen apology over the top of it would
/// be the wrong shape.
struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(ErrorText.friendly(message))
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)

            if let retry {
                Button("Retry", action: retry)
                    .font(.caption.bold())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

enum ErrorText {
    /// `URLError`'s descriptions are the only ones worth putting in front of a
    /// user — they say something true and actionable ("The Internet connection
    /// appears to be offline"). Everything else reaching this point is a
    /// PostgREST or decoding message that means nothing outside Xcode.
    static func friendly(_ message: String) -> String {
        let networkWords = ["offline", "Internet connection", "network connection",
                            "timed out", "could not be found", "not connect to the server"]
        if networkWords.contains(where: { message.localizedCaseInsensitiveContains($0) }) {
            return message
        }
        return "Something went wrong. Please try again."
    }
}

#Preview {
    VStack(spacing: 30) {
        ErrorBlock(message: "The Internet connection appears to be offline.") {}
        ErrorBlock(message: "PGRST116: JSON object requested, multiple rows returned")
        ErrorBanner(message: "The Internet connection appears to be offline.") {}
    }
    .padding()
}
