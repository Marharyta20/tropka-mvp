import SwiftUI

/// Grid of the bundled avatars. Uploading a photo is deliberately not offered —
/// the preset set keeps every profile on-style and sidesteps moderation.
struct AvatarPickerView: View {

    let current: String?
    let onPick: (Avatar) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Avatar?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Avatar.presets) { avatar in
                        Button {
                            selected = avatar
                        } label: {
                            AvatarView(stored: avatar.storedValue, size: 96)
                                .overlay(
                                    Circle().strokeBorder(
                                        isSelected(avatar) ? Color.accentColor : .clear,
                                        lineWidth: 3
                                    )
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    if isSelected(avatar) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, Color.accentColor)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose your avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let selected { onPick(selected) }
                        dismiss()
                    }
                    .bold()
                    .disabled(selected == nil)
                }
            }
            .onAppear {
                selected = Avatar.preset(from: current)
            }
        }
    }

    private func isSelected(_ avatar: Avatar) -> Bool {
        selected?.id == avatar.id
    }
}
