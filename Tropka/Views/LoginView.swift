import SwiftUI

struct LoginView: View {
  @ObservedObject var authVM: AuthViewModel
  @State private var email = ""
  @State private var password = ""
  @State private var error: String?

  var body: some View {
    VStack(spacing: 20) {
      TextField("Email", text: $email)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
      SecureField("Password", text: $password)
        .textFieldStyle(.roundedBorder)

      if let error {
        Text(error).foregroundColor(.red).multilineTextAlignment(.center)
      }

      Button("Sign In") {
        Task {
          do {
            try await authVM.signIn(email: email, password: password)
          } catch {
            self.error = error.localizedDescription
          }
        }
      }

      Button("Sign Up") {
        Task {
          do {
            try await authVM.signUp(email: email, password: password)
          } catch {
            self.error = error.localizedDescription
          }
        }
      }
    }
    .padding()
  }
}
