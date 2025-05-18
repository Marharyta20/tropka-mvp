import SwiftUI

struct RoutesListView: View {
    @StateObject private var vm = RoutesViewModel()   // теперь тип найден

    var body: some View {
        NavigationView {
            List(vm.routes) { route in               // Route : Identifiable
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(.headline)

                    // в модели сейчас authorUID – показываем его для примера
                    Text("by \(route.authorUID)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                Button("Sign Out") {
                    try? AuthService.shared.signOut()
                }
            }
            .overlay {                                // простая индикация загрузки
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
