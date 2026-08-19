import CoreLocation
import SDWebImageSwiftUI
import SwiftUI

// MARK: - Route details

/// One route, top to bottom: what it is, who made it, where it goes.
/// Everything secondary lives in the top bar or in a menu so the screen has one
/// obvious thing to do — start walking it.
struct TourDetailsView: View {
    let route: TourRoute
    /// Where the user came from — lets us compare Explore vs Map vs Profile as entry points.
    var source: Analytics.Source = .explore
    let locationManager = CLLocationManager()

    @StateObject private var vm = TourDetailsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMap = false
    @State private var showReviewSheet = false
    @State private var showEditor = false
    @State private var showDescription = false
    @State private var scrollY: CGFloat = 0

    /// The route as last read from the database, falling back to what we were
    /// handed. Editing or publishing refreshes vm.route, and the whole screen
    /// follows — the header used to keep showing the stale copy.
    private var shown: TourRoute { vm.route ?? route }
    private var isAuthor: Bool { shown.isMine }

    private var totalMinutes: Int {
        let fromStops = vm.stops.reduce(0) { $0 + $1.timeSpent }
        return fromStops > 0 ? fromStops : shown.duration
    }

    /// Real walking distance, once Mapbox has resolved the path between stops.
    private var walkingDistance: String? {
        let coords = vm.routeCoords
        guard coords.count > 1 else { return nil }
        let meters = zip(coords, coords.dropFirst()).reduce(0.0) { total, pair in
            total + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
        guard meters > 100 else { return nil }
        return String(format: "%.1f km", meters / 1000)
    }

    /// The photo scrolls away before the title does, so the bar fades in over the
    /// gap rather than popping.
    private var barOpacity: Double {
        min(max((scrollY - 190) / 60, 0), 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                hero
                header
                metaRow
                if shown.description != nil { aboutRow }
                if !shown.tags.isEmpty { tagRow }
                stopsSection
                reviewsSection
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollY = newValue
        }
        .overlay(alignment: .top) { topBar }
        .safeAreaInset(edge: .bottom) {
            if !vm.stops.isEmpty { startBar }
        }
        .navigationBarHidden(true)
        .trackScreen("RouteDetails", [
            "route_id": route.id,
            "route_title": route.title,
            "source": source.rawValue,
            "rating": route.rating,
            "stops_count": route.stopsCount
        ])
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            Task { await vm.load(routeID: route.id) }
        }
        .sheet(isPresented: $showReviewSheet) {
            ReviewFormSheet(
                draft: vm.myReview ?? UserReview(
                    id: "", routeID: route.id,
                    userID: supabase.auth.currentUser?.id.uuidString ?? "",
                    routeTitle: route.title, rating: 5, text: "", createdAt: .now
                )
            ) { review in
                Analytics.track(.reviewSubmitted, [
                    "route_id": route.id,
                    "rating": review.rating,
                    "text_length": review.text.count,
                    "is_edit": vm.myReview != nil
                ])
                Task { await vm.saveReview(review) }
            }
        }
        .sheet(isPresented: $showDescription) {
            RouteDescriptionSheet(title: shown.title, text: shown.description ?? "")
        }
        .navigationDestination(isPresented: $showMap) {
            RouteMapView(vm: vm)
        }
        .navigationDestination(isPresented: $showEditor) {
            RouteEditorView(mode: .edit(routeID: route.id)) {
                Task { await vm.load(routeID: route.id) }
            }
        }
    }

    // MARK: - Top bar

    /// Transparent over the photo, frosted once the title would otherwise be gone.
    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton("chevron.left") { dismiss() }

            Text(shown.title)
                .font(.subheadline.bold())
                .lineLimit(1)
                .opacity(barOpacity)
                .frame(maxWidth: .infinity)

            if !isAuthor {
                circleButton(vm.isSaved ? "bookmark.fill" : "bookmark") {
                    Task {
                        if vm.isSaved {
                            Analytics.track(.routeUnsaved, [
                                "route_id": route.id,
                                "route_title": route.title,
                                "source": "route_details"
                            ])
                            await vm.unsaveRoute(routeID: route.id)
                        } else {
                            Analytics.track(.routeSaved, [
                                "route_id": route.id,
                                "route_title": route.title,
                                "source": "route_details"
                            ])
                            await vm.saveRoute(routeID: route.id)
                        }
                    }
                }
            } else {
                authorMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(barOpacity)
                .ignoresSafeArea(edges: .top)
        }
        .animation(.easeOut(duration: 0.15), value: barOpacity)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    /// Everything only the author can do lives here instead of competing with the
    /// reader's actions.
    private var authorMenu: some View {
        Menu {
            Button {
                Analytics.track(.routeEditorOpened, [
                    "mode": "edit",
                    "route_id": route.id,
                    "source": "route_details"
                ])
                showEditor = true
            } label: {
                Label("Edit route", systemImage: "slider.horizontal.3")
            }

            Picker("Visibility", selection: Binding(
                get: { shown.status },
                set: { newValue in
                    Task { await vm.setStatus(routeID: route.id, status: newValue) }
                }
            )) {
                ForEach(RouteStatus.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    // MARK: - Hero

    private var hero: some View {
        Group {
            if let url = shown.thumbnailURL {
                WebImage(url: url) { $0.resizable().scaledToFill() }
                    placeholder: { Color(.systemGray5) }
            } else {
                LinearGradient(colors: [.blue.opacity(0.7), .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shown.title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let author = shown.authorName {
                    AvatarView(stored: shown.authorAvatar, size: 26)
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                // Only the author can see a non-public route at all,
                // so the badge never leaks anything.
                if shown.status != .public {
                    RouteStatusBadge(status: shown.status)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// One line, one colour. The old three-column pill row with a yellow star, a
    /// blue clock and a red pin was louder than the title above it.
    private var metaRow: some View {
        HStack(spacing: 6) {
            if shown.rating > 0 {
                Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                Text(String(format: "%.1f", shown.rating))
                if shown.reviewCount > 0 {
                    Text("(\(shown.reviewCount))").foregroundColor(.secondary)
                }
                Text("·").foregroundColor(.secondary)
            }
            Text("\(shown.stopsCount) stops")
            Text("·")
            Text(totalMinutes.formattedDuration)
            if let walkingDistance {
                Text("·")
                Text(walkingDistance)
            }
            Spacer(minLength: 0)
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
    }

    private var aboutRow: some View {
        Button {
            Analytics.track(.routeDescriptionOpened, ["route_id": route.id])
            showDescription = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                Text("About this route").font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shown.tags, id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Color(.systemGray4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Stops

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stops")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(32)
            } else if vm.stops.isEmpty {
                Text("No stops added yet")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                    // Every stop is a curated place, so it should open like one.
                    NavigationLink {
                        PlaceDetailView(placeID: stop.placeID)
                    } label: {
                        StopRow(stop: stop, index: index, total: vm.stops.count)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.routeStopOpened, [
                            "route_id": route.id,
                            "place_id": stop.placeID,
                            "place_name": stop.name,
                            "order_index": stop.orderIndex
                        ])
                    })
                }
            }
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Reviews").font(.headline)
                if !vm.reviews.isEmpty {
                    Text("\(vm.reviews.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Reviewing is for people who kept the route; the author rates nothing.
                if vm.isSaved {
                    Button(vm.myReview == nil ? "Write" : "Edit") {
                        Analytics.track(.reviewFormOpened, [
                            "route_id": route.id,
                            "is_edit": vm.myReview != nil
                        ])
                        showReviewSheet = true
                    }
                    .font(.subheadline.bold())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if vm.reviews.isEmpty {
                Text("No reviews yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ForEach(vm.reviews) { review in
                    PublicReviewRow(review: review)
                    if review.id != vm.reviews.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }

    // MARK: - Primary action

    /// The one thing this screen is for.
    private var startBar: some View {
        Button {
            Analytics.track(.routeMapOpened, [
                "route_id": route.id,
                "route_title": route.title,
                "stops_count": vm.stops.count
            ])
            showMap = true
        } label: {
            Label("Start walking", systemImage: "figure.walk")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Stop row (timeline style)

private struct StopRow: View {
    let stop: Stop
    let index: Int
    let total: Int

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Timeline dot + connecting lines
            VStack(spacing: 0) {
                Rectangle().fill(Color(.systemGray4)).frame(width: 2)
                    .opacity(index == 0 ? 0 : 1)
                ZStack {
                    Circle().fill(Color.accentColor).frame(width: 26, height: 26)
                    Text("\(stop.orderIndex)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                Rectangle().fill(Color(.systemGray4)).frame(width: 2)
                    .opacity(index == total - 1 ? 0 : 1)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.body.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    // No clock glyph here — the "≈ N min" already reads as a duration.
                    Text("≈ \(stop.timeSpent) min").font(.caption)
                    if let notes = stop.notes, !notes.isEmpty {
                        Text("· \(notes)").font(.caption).lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.trailing, 8)

            Spacer(minLength: 0)

            PlaceThumbnail(url: stop.photoURL,
                           category: stop.category,
                           thumbnailPixelSize: CGSize(width: 200, height: 200))
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, 20)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Public review row

private struct PublicReviewRow: View {
    let review: UserReview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(stored: review.authorAvatar, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(review.isMine ? "You" : (review.authorName ?? "Someone"))
                        .font(.subheadline.bold())
                    Stars(rating: review.rating)
                    Spacer(minLength: 0)
                    Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !review.text.isEmpty {
                    Text(review.text)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Description sheet

private struct RouteDescriptionSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Review form sheet

struct ReviewFormSheet: View {
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
                Section("Your thoughts") {
                    TextEditor(text: $draft.text).frame(height: 120)
                }
            }
            .navigationTitle("Leave a review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }.bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
