import SwiftUI

/// Settings, in the shape the App Store expects.
///
/// The previous version was a column of two fields and three buttons: no way to
/// see which account you were in, no way to change a password you still knew
/// (only to recover one you had forgotten), and no privacy policy anywhere —
/// which a reviewer looks for in an app that has accounts.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileVM: ProfileViewModel
    @StateObject private var vm: SettingsViewModel = .init()

    @State private var showSaved = false
    @State private var showDeleteConfirm = false
    @State private var showPasswordSheet = false
    @ObservedObject private var push = PushService.shared

    var body: some View {
        Form {
            profileSection
            accountSection
            notificationsSection
            aboutSection
            dangerSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Settings")
        .overlay {
            if vm.isBusy {
                ProgressView().controlSize(.large)
            }
        }
        .sheet(isPresented: $showPasswordSheet) {
            ChangePasswordSheet(vm: vm)
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task {
                    guard await vm.deleteAccount() else { return }
                    Analytics.track(.accountDeleted)
                    Analytics.reset()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your routes, reviews and saved routes are deleted with it. This cannot be undone.")
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
        .task { await vm.load() }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Your name", text: $vm.displayName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
            Button("Save changes") {
                Task {
                    // Nothing is reported, and nothing is copied into the profile
                    // header, until the database has taken it.
                    guard await vm.save() else { return }
                    Analytics.track(.settingsSaved)
                    profileVM.displayName = vm.displayName
                    showSaved = true
                }
            }
            .disabled(!vm.isLoaded || vm.isBusy || !vm.hasChanges)
        } header: {
            Text("Profile")
        } footer: {
            Text("Your name is shown on routes and reviews you publish.")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Email") {
                Text(vm.email.isEmpty ? "—" : vm.email)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Change password") { showPasswordSheet = true }
            Button("Sign out", role: .destructive) {
                Analytics.track(.signedOut, ["source": "settings"])
                Analytics.reset()
                vm.signOut()
                dismiss()
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            switch push.systemStatus {
            case .denied:
                // Prompting again does nothing: iOS shows the sheet once. The
                // only honest move is to say where the switch actually lives.
                LabeledContent("Notifications") {
                    Text("Off in iOS Settings").foregroundColor(.secondary)
                }
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)

            case .notDetermined:
                Button("Turn on notifications") {
                    Task { await push.requestPermission() }
                }

            default:
                Toggle("Notifications", isOn: Binding(
                    get: { push.isEnabled },
                    set: { value in Task { await push.setEnabled(value) } }
                ))
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("When someone reviews a route you published.")
        }
        .task { await push.loadEnabled(); await push.refreshStatus() }
    }

    private var aboutSection: some View {
        Section("About") {
            Link(destination: Legal.privacyPolicy) {
                LabeledContent("Privacy Policy") {
                    Image(systemName: "arrow.up.right").font(.caption)
                }
            }
            Link(destination: Legal.terms) {
                LabeledContent("Terms of Use") {
                    Image(systemName: "arrow.up.right").font(.caption)
                }
            }
            Link(destination: Legal.support) {
                LabeledContent("Contact us") {
                    Image(systemName: "arrow.up.right").font(.caption)
                }
            }
            LabeledContent("Version") {
                Text(vm.appVersion).foregroundColor(.secondary)
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Delete account", role: .destructive) {
                showDeleteConfirm = true
            }
        } footer: {
            Text("Deleting removes your profile, routes, reviews and saved routes permanently.")
        }
    }
}

// MARK: - Change password

private struct ChangePasswordSheet: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var done = false

    private var canSubmit: Bool {
        !current.isEmpty && new.count >= 6 && new == confirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current password", text: $current)
                        .textContentType(.password)
                } footer: {
                    // Supabase accepts the session as proof and does not require
                    // the old password. Asking anyway means an unlocked phone
                    // left on a table is not one tap from a new password.
                    Text("We ask for it to make sure it's you.")
                }

                Section {
                    SecureField("New password", text: $new)
                        .textContentType(.newPassword)
                    SecureField("Repeat new password", text: $confirm)
                        .textContentType(.newPassword)
                } footer: {
                    if !new.isEmpty && new.count < 6 {
                        Text("At least 6 characters.").foregroundColor(.tropkaCoral)
                    } else if !confirm.isEmpty && new != confirm {
                        Text("The two don't match.").foregroundColor(.tropkaCoral)
                    } else {
                        Text("At least 6 characters.")
                    }
                }
            }
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard await vm.changePassword(current: current, new: new) else { return }
                            done = true
                        }
                    }
                    .disabled(!canSubmit || vm.isBusy)
                }
            }
            .overlay {
                if vm.isBusy { ProgressView().controlSize(.large) }
            }
            .alert("Password changed", isPresented: $done) {
                Button("OK") { dismiss() }
            }
        }
    }
}
