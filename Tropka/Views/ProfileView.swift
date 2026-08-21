import SDWebImageSwiftUI
import SwiftUI

/// The profile: who you are, and the three piles of things you own — saved routes,
/// routes you wrote, reviews you left.
struct ProfileView: View {

    @StateObject private var vm = ProfileViewModel()

    @State private var showSettings = false
    @State private var selectedTab: Tab = .saved
    @Namespace private var underlineNS

    @State private var pendingDelete: SavedRoute?
    @State private var showDeleteConfirm = false
    @State private var editingReview: UserReview?

    @State private var pendingCreatedDelete: TourRoute?
    @State private var showCreatedDeleteConfirm = false
    @State private var showNewRoute = false
    @State private var showAvatarPicker = false

    enum Tab: CaseIterable {
        case saved, created, walked, reviews

        var title: String {
            switch self {
            case .saved:   return "Saved"
            case .created: return "Created"
            case .walked:  return "Walked"
            case .reviews: return "Reviews"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                if let errorMessage = vm.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await vm.fetchAll() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                actionRow
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                tabBar
                    .padding(.top, 18)
                tabContent
            }
            .padding(.top, 4)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(profileVM: vm)
            }
            .navigationDestination(isPresented: $showNewRoute) {
                RouteEditorView(mode: .create) {
                    Task { await vm.fetchCreatedRoutes() }
                }
            }
            .trackScreen("Profile")
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView(current: vm.avatarValue) { avatar in
                Task { await vm.setAvatar(avatar) }
            }
        }
        .sheet(item: $editingReview) { review in
            EditReviewSheet(draft: review) { updated in
                Analytics.track(.reviewSubmitted, [
                    "route_id": updated.routeID,
                    "rating": updated.rating,
                    "text_length": updated.text.count,
                    "is_edit": true,
                    "source": Analytics.Source.profile.rawValue
                ])
                Task { await vm.update(review: updated) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                showAvatarPicker = true
            } label: {
                AvatarView(stored: vm.avatarValue, size: 78)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.isLoadingProfile ? "…" : (vm.displayName.isEmpty ? "No name yet" : vm.displayName))
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let joined = vm.registrationDate {
                    Text("Joined \(joined.formatted(.dateTime.month(.wide).year()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        let handle = vm.handle.isEmpty ? "" : "@\(vm.handle)"
        return [handle, vm.city].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                showSettings = true
            } label: {
                Text("Edit profile")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            ShareLink(item: shareProfileText) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .simultaneousGesture(TapGesture().onEnded {
                Analytics.track(.profileShared)
            })
        }
    }

    /// Plain-text invite for now — swap in a real App Store / profile URL once one exists.
    private var shareProfileText: String {
        "Check out my profile on Tropka! I'm @\(vm.handle) 🗺️"
    }

    // MARK: - Tabs

    /// Counts live in the tabs themselves: the old screen made you open each one to
    /// find out whether there was anything inside.
    private func count(for tab: Tab) -> Int {
        switch tab {
        case .saved:   return vm.routes.count
        case .created: return vm.createdRoutes.count
        case .walked:  return vm.walkedRoutes.count
        case .reviews: return vm.myReviews.count
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    Analytics.track(.profileTabSwitched, ["tab": String(describing: tab)])
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Text(tab.title)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                // Four tabs plus their count pills is a tight fit
                                // on the narrowest phones.
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if count(for: tab) > 0 {
                                Text("\(count(for: tab))")
                                    .font(.caption2.bold())
                                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(selectedTab == tab
                                                       ? Color.accentColor
                                                       : Color(.systemGray5))
                                    )
                            }
                        }

                        Group {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: underlineNS)
                            } else {
                                Color.clear.frame(height: 2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .saved:   savedList
        case .created: createdList
        case .walked:  walkedList
        case .reviews: reviewsList
        }
    }

    // MARK: - Saved

    private var savedList: some View {
        List {
            ForEach(vm.routes) { item in
                NavigationLink {
                    SavedRouteMapScreen(routeID: item.route.id, title: item.route.title)
                } label: {
                    RouteRow(route: item.route, caption: savedCaption(item))
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDelete = item
                        showDeleteConfirm = true
                    } label: { Label("Remove", systemImage: "bookmark.slash") }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.routes.isEmpty {
                ContentUnavailableView("Nothing saved yet",
                                       systemImage: "bookmark",
                                       description: Text("Routes you save from Explore or the map show up here."))
            }
        }
        .confirmationDialog("Remove this route?", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) {
                if let item = pendingDelete {
                    Analytics.track(.routeUnsaved, [
                        "route_id": item.route.id,
                        "route_title": item.route.title,
                        "source": Analytics.Source.profile.rawValue
                    ])
                    Task { await vm.unsave(routeID: item.route.id) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func savedCaption(_ item: SavedRoute) -> String? {
        guard let date = item.savedAt else { return nil }
        return "Saved \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Created

    /// Everything the user has actually finished. Saved is what they might do;
    /// this is what they did.
    private var walkedList: some View {
        List {
            ForEach(vm.walkedRoutes) { route in
                NavigationLink {
                    TourDetailsView(route: route, source: .profile)
                } label: {
                    RouteRow(route: route)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.walkedRoutes.isEmpty {
                ContentUnavailableView("Nothing walked yet",
                                       systemImage: "figure.walk",
                                       description: Text("Mark a route as walked on its page and it shows up here."))
            }
        }
        .task { await vm.fetchWalkedRoutes() }
        .refreshable { await vm.fetchWalkedRoutes() }
    }

    private var createdList: some View {
        List {
            // Lives inside the list it adds to, rather than in the navigation bar
            // where it would sit on every tab and belong to none of them.
            if !vm.createdRoutes.isEmpty {
                Button {
                    Analytics.track(.routeEditorOpened, [
                        "mode": "create",
                        "draft_size": RouteDraftStore.shared.count
                    ])
                    showNewRoute = true
                } label: {
                    newRouteRow
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
            }

            ForEach(vm.createdRoutes) { route in
                NavigationLink {
                    TourDetailsView(route: route, source: .profile)
                } label: {
                    RouteRow(route: route, caption: nil, showsStatus: true)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
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
                ContentUnavailableView {
                    Label("No routes yet", systemImage: "map")
                } description: {
                    Text("Pick places you like on the map, then put them in order.")
                } actions: {
                    Button("New route") {
                        Analytics.track(.routeEditorOpened, [
                            "mode": "create",
                            "draft_size": RouteDraftStore.shared.count
                        ])
                        showNewRoute = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .confirmationDialog("Delete this route? This cannot be undone.",
                            isPresented: $showCreatedDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let route = pendingCreatedDelete {
                    Task { await vm.deleteCreated(routeID: route.id) }
                }
            }
            Button("Cancel", role: .cancel) { pendingCreatedDelete = nil }
        }
        .task { await vm.fetchCreatedRoutes() }
        .refreshable { await vm.fetchCreatedRoutes() }
    }

    private var newRouteRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("New route")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(RouteDraftStore.shared.isEmpty
                     ? "Pick places and put them in order"
                     : "\(RouteDraftStore.shared.count) place\(RouteDraftStore.shared.count == 1 ? "" : "s") waiting from the map")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    // MARK: - Reviews

    private var reviewsList: some View {
        List {
            ForEach(vm.myReviews) { review in
                ReviewRow(review: review)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button(role: .destructive) {
                            Analytics.track(.reviewDeleted, [
                                "route_id": review.routeID,
                                "rating": review.rating
                            ])
                            Task { await vm.delete(review: review) }
                        } label: { Label("Delete", systemImage: "trash") }

                        Button {
                            Analytics.track(.reviewFormOpened, [
                                "route_id": review.routeID,
                                "is_edit": true,
                                "source": Analytics.Source.profile.rawValue
                            ])
                            editingReview = review
                        } label: { Label("Edit", systemImage: "pencil") }
                    }
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.myReviews.isEmpty {
                ContentUnavailableView("No reviews yet",
                                       systemImage: "star",
                                       description: Text("Save a route, walk it, then tell people how it went."))
            }
        }
        .onAppear { vm.loadReviews() }
    }
}

// MARK: - Route row

/// One row for both piles. The old version carried a blue "Saved" pill on every
/// line inside the Saved tab — restating the tab you were already on, and squeezing
/// every title down to "Classic Wars…".
private struct RouteRow: View {
    let route: TourRoute
    var caption: String?
    var showsStatus = false

    /// Read from the shared store rather than passed in, so a route marked walked
    /// anywhere in the app is marked here too, on every tab it appears on.
    @ObservedObject private var walkedStore = WalkedRoutesStore.shared

    private var isWalked: Bool { walkedStore.contains(route.id) }

    var body: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(route.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    if route.rating > 0 {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                        Text(String(format: "%.1f", route.rating))
                        Text("·")
                    }
                    Text("\(route.stopsCount) stops")
                    Text("·")
                    Text(route.duration.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    if isWalked { WalkedBadge() }

                    if showsStatus, route.status != .public {
                        RouteStatusBadge(status: route.status)
                    } else if let caption {
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var cover: some View {
        Group {
            if let url = route.thumbnailURL {
                WebImage(url: url,
                         context: [.imageThumbnailPixelSize: CGSize(width: 200, height: 200)]) {
                    $0.resizable().scaledToFill()
                } placeholder: {
                    gradient
                }
            } else {
                gradient
            }
        }
    }

    private var gradient: some View {
        LinearGradient(colors: [.blue.opacity(0.7), .indigo],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "map").foregroundStyle(.white.opacity(0.9)))
    }
}

// MARK: - Saved route map

struct SavedRouteMapScreen: View {
    let routeID: String
    let title: String

    @StateObject private var vm = TourDetailsViewModel()

    var body: some View {
        RouteMapView(vm: vm)
            .navigationTitle(title)
            .onAppear {
                Analytics.track(.routeOpened, [
                    "route_id": routeID,
                    "route_title": title,
                    "source": Analytics.Source.profile.rawValue
                ])
                if vm.stops.isEmpty {
                    Task { await vm.load(routeID: routeID) }
                }
            }
    }
}

// MARK: - Review row

struct ReviewRow: View {
    let review: UserReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(review.routeTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer(minLength: 0)
                Stars(rating: review.rating)
            }

            if !review.text.isEmpty {
                Text(review.text)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }

            Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Tiny star stack, also used by the reviews on a route.
struct Stars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Edit review

struct EditReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: UserReview
    let onSave: (UserReview) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    Picker("Rating", selection: $draft.rating) {
                        ForEach(1...5, id: \.self) { Text("\($0) ★") }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Review") {
                    TextEditor(text: $draft.text)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Edit review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }.bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
