import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileVM: ProfileViewModel
    @StateObject private var vm: SettingsViewModel = .init()

    @State private var showSaved = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 28) {

                //–– Full name
                editableField(title: "FULL NAME", text: $vm.displayName,
                              keyboard: UIKeyboardType.default)

                //–– Username
                editableField(title: "USERNAME", text: $vm.username,
                              keyboard: UIKeyboardType.asciiCapable)

                //–– Save
                Button("Save") {
                    Task {
                        let changedName = vm.displayName != profileVM.displayName
                        let changedUsername = vm.username != profileVM.handle
                        await vm.save()
                        Analytics.track(.settingsSaved, [
                            "changed_name": changedName,
                            "changed_username": changedUsername
                        ])
                        profileVM.displayName = vm.displayName
                        profileVM.handle      = vm.username
                        showSaved = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                //–– Sign out
                Button("Sign Out", role: .destructive) {
                    Analytics.track(.signedOut, ["source": "settings"])
                    Analytics.reset()
                    vm.signOut()
                    dismiss()
                }
                .frame(maxWidth: .infinity)

                //–– Delete
                Button("Delete Account", role: .destructive) {
                    Task {
                        Analytics.track(.accountDeleted)
                        await vm.deleteAccount()
                        Analytics.reset()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Settings")
        .overlay {
            if vm.isBusy {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .alert("Changes saved", isPresented: $showSaved) {
            Button("OK", role: .cancel) { }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { _ in vm.error = nil })
        ) { Button("OK", role: .cancel) { } } message: {
            Text(vm.error ?? "")
        }
        .onAppear { vm.prefill(with: profileVM) }
    }

    // MARK: reusable field
    @ViewBuilder
    private func editableField(title: String,
                               text: Binding<String>,
                               keyboard: UIKeyboardType,
                               prefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                if let prefix { Text(prefix).foregroundColor(.secondary) }
                TextField("", text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3))
            )
        }
    }
}

