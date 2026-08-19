import SwiftUI

/// Password recovery in two steps: ask for the address, then take the six-digit
/// code from the email together with the new password.
///
/// Verifying the code signs the user in — that is how Supabase recovery works — so
/// once the new password is saved they are already inside the app.
struct ForgotPasswordView: View {

    private enum Step {
        case requestCode
        case setPassword
    }

    /// Prefilled from the login form, since the address is usually already typed.
    @State var email: String

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .requestCode
    @State private var code = ""
    @State private var newPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var info: String?

    private var canSend: Bool {
        email.contains("@") && !isWorking
    }

    /// Mirrors the rule set in Supabase (Authentication → Providers → Email):
    /// six characters. Checking here means the user learns it before the round
    /// trip, not after.
    private var canSave: Bool {
        code.count >= 6 && newPassword.count >= 6 && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .requestCode: requestSection
                case .setPassword: passwordSection
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                if let info {
                    Text(info)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isWorking)
            .overlay {
                if isWorking { ProgressView() }
            }
        }
        .trackScreen("ForgotPassword")
    }

    // MARK: - Steps

    private var requestSection: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Send code") { Task { await sendCode() } }
                .disabled(!canSend)
        } footer: {
            Text("We'll email you a six-digit code. It is valid for one hour.")
        }
    }

    private var passwordSection: some View {
        Section {
            TextField("Six-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)

            SecureField("New password", text: $newPassword)
                .textContentType(.newPassword)

            Button("Save new password") { Task { await savePassword() } }
                .disabled(!canSave)

            Button("Send another code") { Task { await sendCode() } }
                .font(.footnote)
        } footer: {
            Text("At least 6 characters.")
        }
    }

    // MARK: - Actions

    private func sendCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await AuthService.shared.sendRecoveryCode(email: email)
            Analytics.track(.passwordResetRequested)
            info = "Code sent to \(email). Check spam if it isn't there in a minute."
            step = .setPassword
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePassword() async {
        isWorking = true
        errorMessage = nil
        info = nil
        defer { isWorking = false }

        do {
            try await AuthService.shared.verifyRecoveryCode(email: email, code: code)
            try await AuthService.shared.updatePassword(newPassword)
            Analytics.track(.passwordResetCompleted)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
