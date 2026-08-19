import SwiftUI

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel

    @State private var isSignUpMode = false
    @State private var showForgotPassword = false

    var body: some View {
        VStack(spacing: 20) {

            Text(isSignUpMode ? "Create Account" : "Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)

            if isSignUpMode {
                TextField("Full Name", text: $authVM.fullName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .transition(.opacity)
            }

            TextField("Email", text: $authVM.email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)

            SecureField("Password", text: $authVM.password)
                .textFieldStyle(.roundedBorder)
                .textContentType(isSignUpMode ? .newPassword : .password)

            if !isSignUpMode {
                Button("Forgot password?") {
                    showForgotPassword = true
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            if authVM.isLoading {
                ProgressView()
            }

            Button {
                UIApplication.shared.endEditing()
                if isSignUpMode {
                    authVM.register()
                } else {
                    authVM.login()
                }
            } label: {
                Text(isSignUpMode ? "Sign Up" : "Log In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(authVM.isLoading)
            .padding(.top, 10)

            Button {
                Analytics.track(.authModeToggled, ["to": isSignUpMode ? "log_in" : "sign_up"])
                withAnimation {
                    isSignUpMode.toggle()
                    authVM.errorMessage = nil
                }
            } label: {
                Text(isSignUpMode ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .animation(.default, value: isSignUpMode)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: authVM.email)
        }
        .trackScreen("Login")
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
