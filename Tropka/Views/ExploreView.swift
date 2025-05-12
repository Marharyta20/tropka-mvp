import SwiftUI

struct ExploreView: View {
    @StateObject private var vm = RoutesViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.routes) { route in
                        RouteCardView(route: route)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Explore")
        }
        .onAppear { vm.loadRoutes() }
    }
}

struct RouteCardView: View {
    let route: Route

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: route.thumbnailURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(route.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("by \(route.author)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text("★ \(String(format: "%.1f", route.rating))")
                    Text("•")
                    Text(route.price == 0 ? "Free" : "€\(route.price!, specifier: "%.2f")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
}
