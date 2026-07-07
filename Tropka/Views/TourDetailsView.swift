import SwiftUI
import SDWebImageSwiftUI
import CoreLocation

// MARK: – Route details
struct TourDetailsView: View {
    let route: TourRoute
    let locationManager = CLLocationManager()
    @StateObject private var vm = TourDetailsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMap         = false
    @State private var showReviewSheet = false

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
                        VStack(alignment: .leading, spacing: 8) {
                            Text(route.title)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .fixedSize(horizontal: false, vertical: true)
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
                        if !vm.isLoading && !vm.stops.isEmpty {
                            ActionButton(icon: "map.fill", label: "Map", color: .blue) { showMap = true }
                            Divider().frame(height: 36)
                        }

                        if vm.isSaved {
                            ActionButton(icon: "bookmark.fill", label: "Saved", color: .blue) {
                                Task { await vm.unsaveRoute(routeID: route.id) }
                            }
                            Divider().frame(height: 36)
                            ActionButton(
                                icon: vm.myReview == nil ? "square.and.pencil" : "pencil",
                                label: vm.myReview == nil ? "Review" : "Edit",
                                color: .purple
                            ) { showReviewSheet = true }
                        } else {
                            ActionButton(icon: "bookmark", label: "Save", color: .blue) {
                                Task { await vm.saveRoute(routeID: route.id) }
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
                    .padding(.bottom, 40)
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
            ) { review in Task { await vm.saveReview(review) } }
        }
        .navigationDestination(isPresented: $showMap) {
            RouteMapView(vm: vm)
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
                    Image(systemName: "clock").font(.caption2)
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
