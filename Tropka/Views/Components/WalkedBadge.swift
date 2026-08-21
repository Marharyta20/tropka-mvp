import SwiftUI

/// "Walked" — the mark that a route is done.
///
/// Deliberately says the word rather than showing a bare tick: a checkmark on a
/// route card could just as easily read as "selected", and this is the one piece
/// of state in the app that is about the user's own history.
struct WalkedBadge: View {
    /// Set when the badge sits on a photo. A tinted capsule disappears over a
    /// bright cover, so on covers the background becomes a material instead.
    var onCover = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text("Walked")
                .font(.caption2.bold())
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            if onCover {
                Capsule().fill(.ultraThinMaterial)
            } else {
                Capsule().fill(Color.green.opacity(0.14))
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        WalkedBadge()
        WalkedBadge(onCover: true)
            .padding(20)
            .background(LinearGradient(colors: [.blue, .indigo],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
    }
    .padding()
}
