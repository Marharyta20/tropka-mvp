import SwiftUI
import SDWebImageSwiftUI
import CoreLocation

// MARK: – Route details
struct TourDetailsView: View {
    let route: TourRoute
    /// Where the user came from — lets us compare Explore vs Map vs Profile as entry points.
    var source: Analytics.Source = .explore
    let locationManager = CLLocationManager()
    @StateObject private var vm = TourDetailsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMap         = false
    @State private var showReviewSheet = false
    @State private var showEditor      = false
    @State private var showDescription = false

    /// The route as last read from the database, falling back to what we were
    /// handed. Editing or publishing refreshes vm.route, and the header follows.
    private var shown: TourRoute { vm.route ?? route }
    private var isAuthor: Bool { shown.isMine }

    // Compute duration: prefer sum of stops, else route.duration
    private var totalMinutes: Int {
        let fromStops = vm.stops.reduce(0) { $0 + $1.timeSpent }
        return fromStops > 0 ? fromStops : route.duration
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ── Main scrollable content ──────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero ─────────────────────────────────────────
                    ZStack(alignment: .bottom) {
                        Group {
                            if let url = route.thumbnailURL {
                                WebImage(url: url) { img in img.resizable().scaledToFill() }
                                    placeholder: { Color(.systemGray5) }
                            } else {
                                Color(.systemGray4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()

                        // Gradient overlay
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .center, endPoint: .bottom
                        )
                        .frame(height: 280)

                        // Title overlaid at bottom
                        VStack(alignment: .leading, spacing: 6) {
                            Text(route.title)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 8) {
                                if let author = shown.authorName {
                                    HStack(spacing: 6) {
                                        AvatarView(stored: shown.authorAvatar, size: 26)
                                            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                                        Text("by \(author)")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .shadow(radius: 2)
                                    }
                                }
                                // Only the author can see a non-public route at all,
                                // so the badge never leaks anything.
                                if shown.status != .public {
                                    RouteStatusBadge(status: shown.status)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    // ── Stats row ─────────────────────────────────────
                    HStack(spacing: 0) {
                        StatPill(icon: "star.fill",  value: String(format: "%.1f", route.rating), color: .yellow)
                        Divider().frame(height: 24)
                        StatPill(icon: "clock",      value: totalMinutes.formattedDuration,          color: .blue)
                        Divider().frame(height: 24)
                        StatPill(icon: "mappin",     value: "\(route.stopsCount) stops",           color: .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))

                    // ── Tags ─────────────────────────────────────────
                    if !route.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(route.tags, id: \.self) { tag in
                                    Text(tag.capitalized)
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 10)
                        Divider()
                    }

                    // ── Actions ──────────────────────────────────────
                    HStack(spacing: 0) {
                        if shown.description != nil {
                            ActionButton(icon: "text.alignleft", label: "About", color: .indigo) {
                                Analytics.track(.routeDescriptionOpened, ["route_id": route.id])
                                showDescription = true
                            }
                            Divider().frame(height: 36)
                        }

                        if !vm.isLoading && !vm.stops.isEmpty {
                            ActionButton(icon: "map.fill", label: "Map", color: .blue) {
                                Analytics.track(.routeMapOpened, [
                                    "route_id": route.id,
                                    "route_title": route.title,
                                    "stops_count": vm.stops.count
                                ])
                                showMap = true
                            }
                            Divider().frame(height: 36)
                        }

                        if vm.isSaved {
                            ActionButton(icon: "bookmark.fill", label: "Saved", color: .blue) {
                                Analytics.track(.routeUnsaved, [
                                    "route_id": route.id,
                                    "route_title": route.title,
                                    "source": Analytics.Source.explore.rawValue
                                ])
                                Task { await vm.unsaveRoute(routeID: route.id) }
                            }
                            Divider().frame(height: 36)
                            ActionButton(
                                icon: vm.myReview == nil ? "square.and.pencil" : "pencil",
                                label: vm.myReview == nil ? "Review" : "Edit",
                                color: .purple
                            ) {
                                Analytics.track(.reviewFormOpened, [
                                    "route_id": route.id,
                                    "is_edit": vm.myReview != nil
                                ])
                                showReviewSheet = true
                            }
                        } else if !isAuthor {
                            ActionButton(icon: "bookmark", label: "Save", color: .blue) {
                                Analytics.track(.routeSaved, [
                                    "route_id": route.id,
                                    "route_title": route.title,
                                    "source": "route_details"
                                ])
                                Task { await vm.saveRoute(routeID: route.id) }
                            }
                        }

                        // The author gets editing controls instead of a Save button —
                        // saving your own route to your own saved list makes no sense.
                        if isAuthor {
                            Divider().frame(height: 36)
                            ActionButton(icon: "slider.horizontal.3", label: "Edit", color: .blue) {
                                Analytics.track(.routeEditorOpened, [
                                    "mode": "edit",
                                    "route_id": route.id,
                                    "source": "route_details"
                                ])
                                showEditor = true
                            }
                            Divider().frame(height: 36)
                            Menu {
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
                                VStack(spacing: 4) {
                                    Image(systemName: shown.status.icon)
                                        .font(.system(size: 20, weight: .medium))
                                    Text(shown.status.title)
                                        .font(.caption.bold())
                                }
                                .foregroundColor(shown.status.tint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))

                    Divider()

                    // ── Stops ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Stops")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(32)
                        } else if vm.stops.isEmpty {
                            Text("No stops added yet")
                                .foregroundColor(.secondary)
                                .padding(16)
                        } else {
                            ForEach(Array(vm.stops.enumerated()), id: \.element.id) { idx, stop in
                                StopRow(stop: stop, index: idx, total: vm.stops.count)
                                if idx < vm.stops.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    }
                    // ── Reviews ──────────────────────────────────────
                    if !vm.reviews.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Reviews").font(.headline)
                                Spacer()
                                Text("\(vm.reviews.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                            ForEach(vm.reviews) { review in
                                PublicReviewRow(review: review)
                                if review.id != vm.reviews.last?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .ignoresSafeArea(edges: .top)

            // ── Back button — sits above ScrollView, respects safe area ──
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 16)
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
        .navigationDestination(isPresented: $showMap) {
            RouteMapView(vm: vm)
        }
        .sheet(isPresented: $showDescription) {
            RouteDescriptionSheet(title: shown.title, text: shown.description ?? "")
        }
        .navigationDestination(isPresented: $showEditor) {
            RouteEditorView(mode: .edit(routeID: route.id)) {
                Task { await vm.load(routeID: route.id) }
            }
        }
    }
}

// MARK: – Stat pill
private struct StatPill: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.bold()).foregroundColor(color)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Action button
private struct ActionButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundColor(color)
                Text(label).font(.caption.bold()).foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Stop row (timeline style)
private struct StopRow: View {
    let stop: Stop; let index: Int; let total: Int

    private var dotColor: Color {
        index == 0 ? .green : index == total - 1 ? .red : .blue
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Timeline dot + lines
            VStack(spacing: 0) {
                Rectangle().fill(Color(.systemGray4)).frame(width: 2)
                    .opacity(index == 0 ? 0 : 1)
                ZStack {
                    Circle().fill(dotColor).frame(width: 26, height: 26)
                    Text("\(stop.orderIndex)").font(.caption.bold()).foregroundColor(.white)
                }
                Rectangle().fill(Color(.systemGray4)).frame(width: 2)
                    .opacity(index == total - 1 ? 0 : 1)
            }
            .frame(width: 52)

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.body.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    // No clock glyph here — the "≈ N min" already reads as a duration,
                    // and the icon just crowded the line.
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

            // Thumbnail
            if let url = stop.photoURL {
                WebImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color(.systemGray5) }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.trailing, 16)
            } else {
                Color.clear.frame(width: 0)
            }
        }
        .padding(.leading, 0)
    }
}

// MARK: – Public review row

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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: – Description sheet

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

// MARK: – Review form sheet
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
                    }.pickerStyle(.segmented)
                }
                Section("Your thoughts") {
                    TextEditor(text: $draft.text).frame(height: 120)
                }
            }
            .navigationTitle("Leave a review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(draft); dismiss() }.bold() }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
