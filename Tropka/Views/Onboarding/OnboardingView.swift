import SwiftUI

/// Two screens between signing up and the app.
///
/// It exists because a fresh profile used to be a blank avatar and a username
/// the system invented — `user6246`, shown publicly under the person's name. Both
/// steps can be skipped; nothing here is worth blocking somebody over.
struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @State private var step = 0

    /// Called once the profile has been written, or skipped.
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.tropkaGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $step) {
                    identityStep.tag(0)
                    tasteStep.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .task { await vm.load() }
        .alert("Couldn't save", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { _ in vm.errorMessage = nil })
        ) { Button("OK", role: .cancel) { } } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            // Two dots rather than a percentage: the honest signal here is
            // "this is short", not "you are 50% done".
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.tropkaBlue : Color.primary.opacity(0.15))
                        .frame(width: index == step ? 22 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }

            Spacer()

            Button("Skip") { onFinish() }
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if step == 0 {
                    withAnimation { step = 1 }
                } else {
                    Task {
                        guard await vm.finish() else { return }
                        onFinish()
                    }
                }
            } label: {
                if vm.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(step == 0 ? "Continue" : "Start exploring")
                }
            }
            .buttonStyle(TropkaButtonStyle(isEnabled: vm.canFinish && !vm.isSaving))
            .disabled(!vm.canFinish || vm.isSaving)

            if step == 1 {
                Button("Back") { withAnimation { step = 0 } }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Step 1

    private var identityStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                title("How should we call you?",
                      subtitle: "This is what people see on the routes and reviews you publish.")

                VStack(alignment: .leading, spacing: 10) {
                    Text("PICK AN AVATAR")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                              spacing: 12) {
                        ForEach(Avatar.presets) { preset in
                            Button {
                                vm.avatar = preset
                            } label: {
                                AvatarView(stored: preset.storedValue, size: 64)
                                    .overlay(
                                        Circle().strokeBorder(
                                            vm.avatar == preset ? Color.tropkaBlue : .clear,
                                            lineWidth: 3
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TropkaField(title: "USERNAME", icon: "at") {
                    TextField("username", text: $vm.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Step 2

    private var tasteStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                title("What are you into?",
                      subtitle: "We'll put these first on Explore and on the map. Nothing gets hidden.")

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHERE ARE YOU BASED?")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(vm.cities) { city in
                            chip(city.name, selected: vm.cityID == city.id) {
                                vm.cityID = city.id
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("PICK AS MANY AS YOU LIKE")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(vm.categories) { entry in
                            chip(entry.category.displayName,
                                 icon: entry.category.icon,
                                 selected: vm.interests.contains(entry.category)) {
                                if vm.interests.contains(entry.category) {
                                    vm.interests.remove(entry.category)
                                } else {
                                    vm.interests.insert(entry.category)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Pieces

    private func title(_ text: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ label: String,
                      icon: String? = nil,
                      selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(label).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(selected ? Color.tropkaBlue : Color(.systemBackground))
            )
            .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
