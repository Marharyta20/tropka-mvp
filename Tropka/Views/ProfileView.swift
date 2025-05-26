import SwiftUI

/// Main profile screen

struct ProfileView: View {
    
    // MARK: state & VM
    @StateObject private var vm            = ProfileViewModel()
    @State private   var showSettings      = false
    @State private   var selectedTab: Tab  = .routes
    @Namespace private var underlineNS     // for animation
    
    enum Tab { case routes, reviews }
    
    // MARK: body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    header
                    actionRow
                    tabBar
                    tabContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("")              // empty = no title text
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(profileVM: vm)
            }
        }
    }
    
    // MARK: header
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image("profile-placeholder")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.displayName)                // full name
                    .font(.title3).bold()
                Text("@\(vm.handle) · \(vm.city)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let joined = vm.registrationDate {
                    Text("Joined \(joined.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
    
    // MARK: buttons row
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Edit profile") {
                showSettings = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("Share profile") {
                // TODO: share sheet
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: underline tab bar
    private var tabBar: some View {
        HStack(spacing: 28) {
            tabButton(title: "Your Routes", tab: .routes)
            tabButton(title: "Reviews",     tab: .reviews)
            Spacer()
        }
    }
    private func tabButton(title: String, tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut) { selectedTab = tab }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(.primary)
                if selectedTab == tab {
                    Capsule()
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "underline", in: underlineNS)
                } else {
                    Color.clear.frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .routes:
            if vm.routes.isEmpty {
                Text("No saved routes yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 12) {
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
            
        case .reviews:
            VStack(spacing: 12) {
                ForEach(sampleReviews, id: \.title) { rev in
                    ProfileReviewCell(title: rev.title, text: rev.text)
                }
            }
        }
    }
    
    // placeholder reviews
    private let sampleReviews: [(title: String, text: String)] = [
        ("Hidden Cafés in Warsaw", "Coffee here is top-notch!"),
        ("City Street Art Tour",   "Loved the colorful murals.")
    ]
}


// MARK: mini-screen that shows map of a saved route
extension ProfileView {
    struct SavedRouteMapScreen: View {
        let routeID: String
        let title: String
        
        @StateObject private var vm = TourDetailsViewModel()
        
        var body: some View {
            RouteMapView(vm: vm)
                .navigationTitle(title)
                .onAppear {
                    if vm.stops.isEmpty {
                        vm.loadStops(routeID: routeID)
                    }
                }
        }
    }
}

// MARK: route cell
private struct ProfileRouteCell: View {
    let item: SavedRoute
    
    var body: some View {
        HStack(spacing: 12) {
            // thumbnail
            Group {
                if let url = item.route.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default:
                            Image(systemName: "photo")
                                .resizable().scaledToFit()
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

// MARK: review cell (placeholder)
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
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
