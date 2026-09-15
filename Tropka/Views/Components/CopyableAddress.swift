import SwiftUI
import UIKit

/// The address line, tappable.
///
/// Copying an address is what people came to this screen for half the time —
/// it goes into a messaging app, a taxi, or a maps app that is not this one —
/// and until now the only way to get it out was to retype it off the screen.
///
/// The copy icon is not decoration. Text that does something when tapped and
/// does not say so is text nobody taps, so the affordance has to be visible
/// before the first tap rather than after it. It also does not change: the
/// address is on the clipboard now and stays there, so there is no state here
/// worth drawing — the haptic confirms the tap and the line stays still.
struct CopyableAddress: View {
    let address: String
    /// `PlaceDetailView` leads with a pin; the map sheet already has one above.
    var icon: String? = nil
    var lineLimit: Int? = nil

    var body: some View {
        Button(action: copy) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }

                Text(address)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: lineLimit == nil)

                Image(systemName: "doc.on.doc")
                    .font(.caption2)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(address))
        .accessibilityHint(Text("Copies the address"))
    }

    private func copy() {
        UIPasteboard.general.string = address
        // Copying produces nothing on screen, so this is the whole confirmation.
        // It fires on every tap, including repeats, so a second tap is never
        // silent.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
