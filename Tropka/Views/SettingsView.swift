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

    /// One piece of state for both messages this screen can show.
    ///
    /// There used to be two `.alert` modifiers on the same view, plus a
    /// `.confirmationDialog` and a `.sheet`. SwiftUI resolves one presentation
    /// per view, so a second alert attached to the same place is not a second
    /// alert — the two fight, and what reaches the screen is a half-drawn box
    /// with the dialog underneath still on top of the form.
    ///
    /// A single modifier driven by an enum cannot collide with itself.
    private enum Notice: Equatable {
        case saved
        case failed(String)
        case confirmDelete
    }

    @State private var notice: Notice?
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
        .alert(noticeTitle, isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } })
        ) {
            if notice == .confirmDelete {
                Button("Delete account", role: .destructive) {
                    Task {
                        guard await vm.deleteAccount() else { return }
                        Analytics.track(.accountDeleted)
                        Analytics.reset()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            switch notice {
            case let .failed(text):
                Text(text)
            case .confirmDelete:
                Text("Your routes, reviews and saved routes are deleted with it. This cannot be undone.")
            default:
                EmptyView()
            }
        }
        // The view model reports failures on its own; funnel them into the same
        // one piece of state rather than giving them a second presentation.
        .onChange(of: vm.error) { _, message in
            guard let message else { return }
            notice = .failed(message)
            vm.error = nil
        }
        .task { await vm.load() }
    }

    private var noticeTitle: String {
        switch notice {
        case .failed:        return "Something went wrong"
        case .confirmDelete: return "Delete your account?"
        default:             return "Changes saved"
        }
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
                    notice = .saved
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
                notice = .confirmDelete
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

    /// One alert, two outcomes — same reason as on the screen behind this one.
    /// A failure also has nowhere else to go: the view model is shared, and the
    /// alert on `SettingsView` cannot appear over a sheet that is covering it.
    private enum Outcome: Equatable {
        case changed
        case failed(String)
    }

    @State private var outcome: Outcome?

    private var canSubmit: Bool {
        !current.isEmpty && new.count >= 6 && new == confirm
    }

    private var outcomeTitle: String {
        if case .failed = outcome { return "Couldn't change it" }
        return "Password changed"
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
                    // `.bold()` marks this as the screen's primary action, which
                    // is what the toolbar renders as a filled capsule rather than
                    // a plain one. Every other Save in the app has it; this was
                    // the only one that did not, so it alone came out white.
                    Button("Save") {
                        Task {
                            guard await vm.changePassword(current: current, new: new) else { return }
                            outcome = .changed
                        }
                    }
                    .bold()
                    .disabled(!canSubmit || vm.isBusy)
                }
            }
            .overlay {
                if vm.isBusy { ProgressView().controlSize(.large) }
            }
            .alert(outcomeTitle,
                   isPresented: Binding(get: { outcome != nil },
                                        set: { if !$0 { outcome = nil } })) {
                // Read before clearing: the sheet closes only on success, and a
                // failure has to leave the form standing with what was typed.
                Button("OK") {
                    let succeeded = outcome == .changed
                    outcome = nil
                    if succeeded { dismiss() }
                }
            } message: {
                if case let .failed(text) = outcome { Text(text) }
            }
            .onChange(of: vm.error) { _, message in
                guard let message else { return }
                outcome = .failed(message)
                vm.error = nil
            }
        }
    }
}
