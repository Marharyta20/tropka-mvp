import SwiftUI

struct RoutesListView: View {
  @StateObject private var vm = RoutesViewModel()

  var body: some View {
    NavigationView {
      List(vm.routes) { route in
        VStack(alignment: .leading, spacing: 4) {
          Text(route.title).font(.headline)
          Text("by \(route.author)").font(.subheadline).foregroundColor(.secondary)
        }
      }
      .navigationTitle("Routes")
      .toolbar {
        Button("Sign Out") {
          try? AuthService.shared.signOut()
        }
      }
    }
    .onAppear { vm.loadRoutes() }
  }
}
