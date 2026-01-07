import SwiftUI

struct RoutesListView: View {
    @StateObject private var vm = RoutesViewModel()

    var body: some View {
        NavigationView {
            List(vm.routes) { route in
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(.headline)
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                Button("Sign Out") {
                    AuthService.shared.signOut()
                }
            }
            .overlay {
                if vm.isLoading { ProgressView() }
            }
            .alert("Error", isPresented: .constant(vm.errorMsg != nil)) {
                Button("OK") { vm.errorMsg = nil }
            } message: {
                Text(vm.errorMsg ?? "")
            }
        }
        .onAppear { vm.loadRoutes() }
    }
}
