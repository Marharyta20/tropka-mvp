import MapKit
import SDWebImageSwiftUI
import SwiftUI

/// Everything the catalogue knows about one place, plus the ways to act on it:
/// put it in a route, open its site, see which routes already pass through it.
struct PlaceDetailView: View {

    let placeID: Int
    /// The feed already has most of the data, so the screen can render instantly
    /// and refresh in the background rather than showing a spinner.
    var preloaded: PlaceDetails?

    @Environment(\.dismiss) private var dismiss

    @State private var place: PlaceDetails?
    @State private var relatedRoutes: [TourRoute] = []
    @State private var isLoadingRoutes = false
    @State private var showAddToRoute = false
    @State private var showAllHours = false
    @State private var errorMessage: String?

    private var shown: PlaceDetails? { place ?? preloaded }

    var body: some View {
        ScrollView {
            if let shown {
                VStack(alignment: .leading, spacing: 20) {
                    hero(shown)
                    header(shown)
                    actions(shown)
                    if let summary = shown.summary {
                        about(summary, place: shown)
                    }
                    if !shown.highlights.isEmpty {
                        PlaceHighlightsRow(highlights: shown.highlights)
                            .padding(.horizontal, 20)
                    }
                    if !shown.tags.isEmpty { tagRow(shown) }
                    if let notes = shown.notes { tropkaNote(notes) }
                    if let description = shown.description { quote(description) }
                    if !shown.week.isEmpty { hours(shown) }
                    if let coordinate = shown.coordinate { miniMap(coordinate, name: shown.name) }
                    relatedSection
                }
                .padding(.bottom, 32)
            } else if let errorMessage {
                ErrorBlock(message: errorMessage) {
                    Task { await load() }
                }
                .padding(.top, 80)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddToRoute) {
            if let shown {
                AddToRoutePicker(placeID: shown.id,
                                 placeName: shown.name,
                                 placePhotoURL: shown.photoURL)
            }
        }
        .trackScreen("PlaceDetails", ["place_id": placeID])
        .task { await load() }
    }

    // MARK: - Sections

    private func hero(_ place: PlaceDetails) -> some View {
        PlaceThumbnail(url: place.photoURL, category: place.category)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipped()
            // Wikimedia photos may be used freely, but only with credit.
            .overlay(alignment: .bottomTrailing) {
                if let credit = place.photoAttribution {
                    Text(credit)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(8)
                }
            }
    }

    private func header(_ place: PlaceDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(place.category.displayName, systemImage: place.category.icon)
                    .font(.caption)
                    .foregroundColor(Color(place.category.color))

                GoogleRating(rating: place.rating, sourceURL: place.sourceURL)

                if let price = place.priceRange {
                    Text(price).font(.caption).foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                if let isOpen = place.isOpenNow {
                    Text(isOpen ? "Open now" : "Closed")
                        .font(.caption.bold())
                        .foregroundColor(isOpen ? .green : .red)
                }
                if let today = place.todayHours {
                    Text("· \(today)").font(.caption).foregroundColor(.secondary)
                }
            }

            if let address = place.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }

    private func actions(_ place: PlaceDetails) -> some View {
        HStack(spacing: 10) {
            Button {
                showAddToRoute = true
            } label: {
                Label("Add to route", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if let link = place.link {
                Link(destination: link) {
                    Label("Website", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.placeLinkOpened, ["place_id": place.id])
                })
            }
        }
        .padding(.horizontal, 20)
    }

    private func tagRow(_ place: PlaceDetails) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(place.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Tropka's own comment gets the loudest treatment on the screen — it is the
    /// reason to read this instead of a map app.
    private func tropkaNote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tropka says", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundColor(.orange)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    /// What the place is. Plain text, high on the screen, because it is the first
    /// thing somebody deciding whether to walk there needs.
    @ViewBuilder
    private func about(_ text: String, place: PlaceDetails) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.callout)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // CC BY-SA is not a formality: the licence is conditional on naming
            // the source and making it reachable. The link carries the second
            // half so the URL itself never has to be printed.
            if let attribution = place.summaryAttribution {
                if let url = place.summaryURL {
                    Link(destination: url) {
                        HStack(spacing: 3) {
                            Text(attribution)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                } else {
                    Text(attribution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// What somebody said about it. Italics and quotation marks belong here and
    /// only here.
    private func quote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What people say")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text("“\(text)”")
                .font(.callout)
                .italic()
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    private func hours(_ place: PlaceDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showAllHours.toggle() }
            } label: {
                HStack {
                    Text("Opening hours").font(.headline)
                    Spacer()
                    Image(systemName: showAllHours ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            ForEach(place.week.filter { showAllHours || $0.isToday }, id: \.day) { row in
                HStack {
                    Text(row.day)
                        .font(.subheadline)
                        .fontWeight(row.isToday ? .semibold : .regular)
                    Spacer()
                    Text(row.hours)
                        .font(.subheadline)
                        .foregroundColor(row.isToday ? .primary : .secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func miniMap(_ coordinate: CLLocationCoordinate2D, name: String) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(name, coordinate: coordinate)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Routes through here").font(.headline)

            if isLoadingRoutes {
                ProgressView()
            } else if relatedRoutes.isEmpty {
                Text("No public route includes this place yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(relatedRoutes) { route in
                    NavigationLink {
                        TourDetailsView(route: route, source: .placeSheet)
                    } label: {
                        RelatedRouteRow(route: route)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.placeRouteTapped, [
                            "place_id": placeID,
                            "route_id": route.id,
                            "route_title": route.title
                        ])
                    })
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loading

    private func load() async {
        isLoadingRoutes = true
        errorMessage = nil
        defer { isLoadingRoutes = false }

        do {
            async let detailsTask = PlacesService.shared.details(id: placeID)
            async let routesTask = try? PlacesService.shared.relatedRoutes(placeID: placeID)

            let (details, routes) = try await (detailsTask, routesTask)
            place = details
            relatedRoutes = routes ?? []
        } catch {
            // Only worth reporting when the screen would otherwise be blank. Opened
            // from the feed, `preloaded` already carries enough to be useful, and an
            // error over working content would be noise.
            if preloaded == nil { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Related route row

private struct RelatedRouteRow: View {
    let route: TourRoute

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = route.thumbnailURL {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: "map").foregroundColor(.secondary))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(route.stopsCount) stops · \(route.duration.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let author = route.authorName {
                    HStack(spacing: 4) {
                        AvatarView(stored: route.authorAvatar, size: 16, userID: route.authorUID)
                        Text("by \(author)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
