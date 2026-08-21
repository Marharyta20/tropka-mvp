import SwiftUI

/// The first screen anybody sees.
///
/// The previous version was a bare `VStack` of `.roundedBorder` fields on white,
/// with a system-blue button — the default look of a SwiftUI tutorial. This one
/// is painted in the app's own colours, taken from the icon the user just
/// tapped, so the app looks like itself from the first second.
struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel

    @State private var isSignUpMode = false
    @State private var showForgotPassword = false
    @FocusState private var focused: Field?

    private enum Field { case name, email, password }

    private var canSubmit: Bool {
        guard !authVM.email.isEmpty, !authVM.password.isEmpty else { return false }
        return isSignUpMode ? !authVM.fullName.isEmpty : true
    }

    var body: some View {
        ZStack {
            Color.tropkaGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    mark
                        .padding(.top, 40)
                        .padding(.bottom, 28)
                    card
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.2), value: isSignUpMode)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: authVM.email)
        }
        .trackScreen("Login")
    }

    // MARK: - Mark

    /// The icon's own shapes, not a logo file: a pin over a lighter ground. It
    /// costs nothing to render and stays sharp at any size.
    private var mark: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.75))
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.tropkaCoral)
            }

            Text("Tropka")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Walking routes worth the detour")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 16) {
            Text(isSignUpMode ? "Create your account" : "Welcome back")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSignUpMode {
                TropkaField(title: "FULL NAME", icon: "person") {
                    TextField("Anna Kowalska", text: $authVM.fullName)
                        .textInputAutocapitalization(.words)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .email }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TropkaField(title: "EMAIL", icon: "envelope") {
                TextField("you@example.com", text: $authVM.email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
            }

            TropkaField(title: "PASSWORD", icon: "lock") {
                SecureField("At least 6 characters", text: $authVM.password)
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }

            if !isSignUpMode {
                Button("Forgot password?") { showForgotPassword = true }
                    .font(.footnote)
                    .foregroundColor(.tropkaBlue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let error = authVM.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(.tropkaCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: submit) {
                // The spinner replaces the label rather than sitting beside it,
                // so the button does not change size mid-tap.
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isSignUpMode ? "Sign up" : "Log in")
                }
            }
            .buttonStyle(TropkaButtonStyle(isEnabled: canSubmit && !authVM.isLoading))
            .disabled(!canSubmit || authVM.isLoading)
            .padding(.top, 4)

            Button {
                Analytics.track(.authModeToggled, ["to": isSignUpMode ? "log_in" : "sign_up"])
                isSignUpMode.toggle()
                authVM.errorMessage = nil
            } label: {
                Text(isSignUpMode ? "Already have an account?" : "New here?")
                    .foregroundColor(.secondary)
                + Text(isSignUpMode ? " Log in" : " Create an account")
                    .foregroundColor(.tropkaBlue)
                    .fontWeight(.semibold)
            }
            .font(.footnote)
            .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.10), radius: 24, y: 10)
        )
    }

    private func submit() {
        UIApplication.shared.endEditing()
        focused = nil
        if isSignUpMode {
            authVM.register()
        } else {
            authVM.login()
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
