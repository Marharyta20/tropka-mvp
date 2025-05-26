import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    
    // MARK: - Tabs
    enum Tab: String, CaseIterable {
        case yourRoutes = "Your Routes"
        case reviews    = "Reviews"
    }
    
    @State private var selectedTab: Tab = .yourRoutes
    
    // Temporary placeholders
    private let sampleRoutes: [String] = [
        "Hidden Cafés in Warsaw",
        "City Street Art Tour"
    ]
    private let sampleReviews: [(title: String, text: String)] = [
        ("Hidden Cafés in Warsaw", "Coffee here is top-notch!"),
        ("City Street Art Tour",   "Loved the colorful murals.")
    ]
    
    struct SavedRouteMapScreen: View {
        let routeID: String
        let title: String
        
        @StateObject private var vm = TourDetailsViewModel()
        
        var body: some View {
            RouteMapView(vm: vm)
                .navigationTitle(title)
                .onAppear {
                    // загружаем остановки один раз
                    if vm.stops.isEmpty {
                        vm.loadStops(routeID: routeID)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var routesSection: some View {
        if vm.routes.isEmpty {
            Text("No saved routes yet")
                .foregroundColor(.secondary)
                .padding(.top, 32)
        } else {
            ForEach(vm.routes) { item in
                NavigationLink {
                    SavedRouteMapScreen(
                        routeID: item.route.id,
                        title:   item.route.title
                    )
                } label: {
                    ProfileRouteCell(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                // MARK: Header
                HStack(spacing: 12) {
                    Image("profile-placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.displayName)
                            .font(.title2).bold()
                        Text(vm.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let joined = vm.registrationDate {
                            Text("Joined \(joined.formatted(date: .long, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // TODO: settings screen
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                
                // Error banner
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // MARK: Segmented control
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // MARK: Content
                ScrollView {
                    VStack(spacing: 12) {
                        switch selectedTab {
                        case .yourRoutes:
                            routesSection
                        case .reviews:
                            ForEach(sampleReviews, id: \.title) { review in
                                ProfileReviewCell(title: review.title, text: review.text)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationBarHidden(true)
            }
            .padding(.top)
        }
    }
}

// MARK: - Cells
private struct ProfileRouteCell: View {
    let item: SavedRoute
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: Thumbnail
            Group {
                if let url = item.route.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray.opacity(0.6))
                        .background(Color.gray.opacity(0.1))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // MARK: Title + date
            VStack(alignment: .leading, spacing: 4) {
                Text(item.route.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let date = item.savedAt {
                    Text("Saved \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // MARK: Status badge
            Text(item.isPurchased ? "Bought" : "Saved")
                .font(.caption2).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(item.isPurchased ? Color.green : Color.blue)
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}



private struct ProfileReviewCell: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Text("5")
            }
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
            HStack {
                Button("Edit") { }
                Spacer()
                Button("Delete") { }
                    .foregroundColor(.red)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
