import SwiftUI

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var isSignUpMode = false

    var body: some View {
        VStack(spacing: 20) {
            
            Text(isSignUpMode ? "Create Account" : "Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)

            if isSignUpMode {
                // Привязка к fullName
                TextField("Full Name", text: $authVM.fullName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)
                    .transition(.opacity)
            }

            TextField("Email", text: $authVM.email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $authVM.password)
                .textFieldStyle(.roundedBorder)

            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            if authVM.isLoading {
                ProgressView()
            }

            Button(action: {
                UIApplication.shared.endEditing()
                if isSignUpMode {
                    authVM.register()
                } else {
                    authVM.login()
                }
            }) {
                Text(isSignUpMode ? "Sign Up" : "Log In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(authVM.isLoading)
            .padding(.top, 10)

            Button(action: {
                Analytics.track(.authModeToggled, ["to": isSignUpMode ? "log_in" : "sign_up"])
                withAnimation {
                    isSignUpMode.toggle()
                    authVM.errorMessage = nil
                }
            }) {
                Text(isSignUpMode ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .animation(.default, value: isSignUpMode)
        .trackScreen("Login")
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
