import SwiftUI

/// Main profile screen

struct ProfileView: View {
    
    // MARK: state & VM
    @StateObject private var vm = ProfileViewModel()
    
    @State private var showSettings  = false
    @State private var selectedTab: Tab = .saved
    @Namespace private var underlineNS
    
    @State private var pendingDelete: SavedRoute?
    @State private var showDeleteConfirm = false
    @State private var editingReview: UserReview?

    @State private var pendingCreatedDelete: TourRoute?
    @State private var showCreatedDeleteConfirm = false
    @State private var showNewRoute = false
    
    enum Tab { case saved, created, reviews }
    
    
    // MARK: body
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header
                actionRow
                tabBar
                tabContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(profileVM: vm)
            }
            .trackScreen("Profile")
        }
        .sheet(item: $editingReview) { rev in
            EditReviewSheet(draft: rev) { new in
                Analytics.track(.reviewSubmitted, [
                    "route_id": new.routeID,
                    "rating": new.rating,
                    "text_length": new.text.count,
                    "is_edit": true,
                    "source": Analytics.Source.profile.rawValue
                ])
                Task { await vm.update(review: new) }
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

            ShareLink("Share profile", item: shareProfileText)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.profileShared)
                })
        }
    }

    // Plain-text invite for now — swap in a real App Store / profile URL once one exists.
    private var shareProfileText: String {
        "Check out my profile on Tropka! I'm @\(vm.handle) 🗺️"
    }
    
    // MARK: underline tab bar
    private var tabBar: some View {
        HStack(spacing: 24) {
            tabButton(title: "Saved",   tab: .saved)
            tabButton(title: "Created", tab: .created)
            tabButton(title: "Reviews", tab: .reviews)
            Spacer()
        }
    }
    private func tabButton(title: String, tab: Tab) -> some View {
        Button {
            Analytics.track(.profileTabSwitched, ["tab": String(describing: tab)])
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
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {

        case .saved:
            routesList

        case .created:
            createdList

        case .reviews:
            reviewsList
        }
    }
    
    // MARK: – Routes list
    private var routesList: some View {
        List {
            ForEach(vm.routes) { item in
                NavigationLink {
                    SavedRouteMapScreen(routeID: item.route.id,
                                        title:    item.route.title)
                } label: {
                    ProfileRouteCell(item: item)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.routeOpened, [
                        "route_id": item.route.id,
                        "route_title": item.route.title,
                        "source": Analytics.Source.profile.rawValue
                    ])
                })
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDelete = item
                        showDeleteConfirm = true
                    } label: { Label("Remove", systemImage: "trash") }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.routes.isEmpty {
                Text("No saved routes yet")
                    .foregroundColor(.secondary)
            }
        }
        .confirmationDialog("Remove this route?",
                            isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let r = pendingDelete {
                    Analytics.track(.routeUnsaved, [
                        "route_id": r.route.id,
                        "route_title": r.route.title,
                        "source": Analytics.Source.profile.rawValue
                    ])
                    Task { await vm.unsave(routeID: r.route.id) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
    
    // MARK: – Created routes
    private var createdList: some View {
        VStack(spacing: 0) {
            Button {
                Analytics.track(.routeEditorOpened, [
                    "mode": "create",
                    "draft_size": RouteDraftStore.shared.count
                ])
                showNewRoute = true
            } label: {
                Label(RouteDraftStore.shared.isEmpty
                      ? "New route"
                      : "New route (\(RouteDraftStore.shared.count) from map)",
                      systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 8)

            List {
                ForEach(vm.createdRoutes) { route in
                    NavigationLink {
                        TourDetailsView(route: route, source: .profile)
                    } label: {
                        CreatedRouteCell(route: route)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.routeOpened, [
                            "route_id": route.id,
                            "route_title": route.title,
                            "status": route.status.rawValue,
                            "source": Analytics.Source.profile.rawValue,
                            "is_own": true
                        ])
                    })
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingCreatedDelete = route
                            showCreatedDeleteConfirm = true
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if vm.createdRoutes.isEmpty {
                    Text("You haven't created any routes yet")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationDestination(isPresented: $showNewRoute) {
            RouteEditorView(mode: .create) {
                Task { await vm.fetchCreatedRoutes() }
            }
        }
        .confirmationDialog("Delete this route? This cannot be undone.",
                            isPresented: $showCreatedDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let r = pendingCreatedDelete {
                    Task { await vm.deleteCreated(routeID: r.id) }
                }
            }
            Button("Cancel", role: .cancel) { pendingCreatedDelete = nil }
        }
        .task { await vm.fetchCreatedRoutes() }
        .refreshable { await vm.fetchCreatedRoutes() }
    }

    // MARK: – Reviews list
    private var reviewsList: some View {
        List {
            ForEach(vm.myReviews) { rev in
                ReviewRow(review: rev)
                    .swipeActions {
                        Button(role: .destructive) {
                            Analytics.track(.reviewDeleted, [
                                "route_id": rev.routeID,
                                "rating": rev.rating
                            ])
                            Task { await vm.delete(review: rev) }
                        } label: { Label("Delete", systemImage: "trash") }

                        Button {
                            Analytics.track(.reviewFormOpened, [
                                "route_id": rev.routeID,
                                "is_edit": true,
                                "source": Analytics.Source.profile.rawValue
                            ])
                            editingReview = rev
                        } label: { Label("Edit", systemImage: "pencil") }
                    }
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.myReviews.isEmpty {
                Text("No reviews yet")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { vm.loadReviews() }
    }
}



// MARK: mini-screen that shows map of a saved route
struct SavedRouteMapScreen: View {
    let routeID: String
    let title: String
    
    @StateObject private var vm = TourDetailsViewModel()
    
    var body: some View {
        RouteMapView(vm: vm)
            .navigationTitle(title)
            .onAppear {
                // Coordinates not loaded yet — fetch the whole model
                if vm.stops.isEmpty {
                    Task { await vm.load(routeID: routeID) }
                }
            }
    }
}

// MARK: – Row
struct ReviewRow: View {
    let review: UserReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.routeTitle).font(.headline)
                Spacer()
                Stars(rating: review.rating)   // helper below
            }
            Text(review.text)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// tiny star stack
struct Stars: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id:\.self) {
                Image(systemName: $0 <= rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .font(.caption2)
            }
        }
    }
}

// MARK: – Edit sheet
struct EditReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: UserReview
    let onSave: (UserReview) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    Picker("Rating", selection: $draft.rating) {
                        ForEach(1...5, id:\.self) { Text("\($0)") }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Review") {
                    TextEditor(text: $draft.text)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Edit Review")
            .toolbar {
                ToolbarItem(placement:.confirmationAction) {
                    Button("Save") {
                        onSave(draft); dismiss()
                    }
                }
                ToolbarItem(placement:.cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
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

            Text("Saved")
                .font(.caption2).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: created route cell
private struct CreatedRouteCell: View {
    let route: TourRoute

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = route.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color(.systemGray5)
                        }
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: "map").foregroundColor(.secondary))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(route.title).font(.headline).lineLimit(1)
                Text("\(route.stopsCount) stops · \(route.duration.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                RouteStatusBadge(status: route.status)
            }

            Spacer()

            if route.reviewCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                    Text(String(format: "%.1f", route.rating)).font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
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
