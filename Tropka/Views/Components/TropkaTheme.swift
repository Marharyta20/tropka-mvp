import SwiftUI

// MARK: - Tropka palette

/// The app's own colours live in the asset catalogue as `TropkaBlue`,
/// `TropkaCoral`, `TropkaSky` and `TropkaLavender`, each with a dark variant so
/// nothing here needs a `colorScheme` check. They are taken from the app icon
/// rather than invented: the blue of the hills, the coral of the pin, the sky
/// behind them. A user who taps the icon and lands on a screen painted in system
/// blue has already been told the app is generic.
///
/// `Color.tropkaBlue` and friends are **not** declared here. Xcode generates an
/// accessor for every colour set in the catalogue, so writing them by hand is a
/// redeclaration of a symbol that already exists.
///
/// Currently used by the sign-in and setup screens only. The rest of the app is
/// still on system blue — deliberately, so the palette can be judged on one
/// screen before 28 call sites move to it.
extension Color {
    /// The icon's own gradient, top-left to bottom-right.
    static var tropkaGradient: LinearGradient {
        LinearGradient(colors: [.tropkaSky, .tropkaLavender],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

// MARK: - Primary button

/// One filled button style, so "the main action" looks the same everywhere it
/// appears instead of being re-specified per screen.
struct TropkaButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.tropkaBlue)
                    .opacity(isEnabled ? 1 : 0.4)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Field

/// A text field that reads as one object with its label, rather than a bordered
/// box floating under a caption.
struct TropkaField<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                content
                    .font(.body)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
