import SwiftUI

/// The card for a pin on the map.
///
/// Presented as a system sheet with detents: the first stop shows the name and the
/// two things you can do with a place, and dragging it up reveals the rest. The
/// previous version rebuilt that behaviour by hand with a drag gesture and a
/// hard-coded fraction of `UIScreen.main.bounds`, which was also wrong on iPad.
struct PlaceSheet: View {
    let place: Place

    @State private var details: PlaceDetails?
    @State private var relatedRoutes: [TourRoute] = []
    @State private var isLoadingRoutes = false
    @State private var showAddToRoute = false

    private var placeID: Int? { Int(place.id) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Kept out of the scroll view on purpose. This is exactly what the
                // small detent shows, and a sheet only resizes when the drag starts
                // on something that does not scroll — so this block is the handle.
                VStack(alignment: .leading, spacing: 20) {
                    header
                    actions
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let summary = details?.summary {
                            Text(summary)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 20)
                        }
                        photo
                        if let highlights = details?.highlights, !highlights.isEmpty {
                            PlaceHighlightsRow(highlights: highlights)
                                .padding(.horizontal, 20)
                        }
                        if let tags = details?.tags, !tags.isEmpty { tagRow(tags) }
                        if let notes = details?.notes { tropkaNote(notes) }
                        relatedSection
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddToRoute) {
            if let placeID {
                AddToRoutePicker(placeID: placeID,
                                 placeName: place.name,
                                 placePhotoURL: place.photoURL)
            }
        }
        .task {
            guard let placeID else { return }
            // The map only fetches what a pin needs, so hours, tags and Tropka's own
            // note are pulled in here.
            async let detailsTask = try? PlacesService.shared.details(id: placeID)
            async let routesTask = try? PlacesService.shared.relatedRoutes(placeID: placeID)
            isLoadingRoutes = true
            let (loaded, routes) = await (detailsTask, routesTask)
            details = loaded
            relatedRoutes = routes ?? []
            isLoadingRoutes = false
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.name)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label(place.category.displayName, systemImage: place.category.icon)
                    .font(.caption)
                    .foregroundColor(Color(place.category.color))

                GoogleRating(rating: place.rating, sourceURL: details?.sourceURL)

                if let isOpen = details?.isOpenNow {
                    Text(isOpen ? "Open now" : "Closed")
                        .font(.caption.bold())
                        .foregroundColor(isOpen ? .green : .red)
                }
            }

            if let address = details?.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                showAddToRoute = true
            } label: {
                Label("Add to route", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if let placeID {
                NavigationLink {
                    PlaceDetailView(placeID: placeID, preloaded: details)
                } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.placeOpened, [
                        "place_id": place.id,
                        "place_name": place.name,
                        "category": place.category.displayName,
                        "source": "map_sheet"
                    ])
                })
            }
        }
        .padding(.horizontal, 20)
    }

    private var photo: some View {
        PlaceThumbnail(url: place.photoURL,
                       category: place.category,
                       thumbnailPixelSize: CGSize(width: 600, height: 400))
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    private func tagRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
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
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
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
                // These cards used to be dead weight — they showed a route and went
                // nowhere. Now they open it.
                ForEach(relatedRoutes) { route in
                    NavigationLink {
                        TourDetailsView(route: route, source: .map)
                    } label: {
                        MapRouteRow(route: route)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.placeRouteTapped, [
                            "place_id": place.id,
                            "route_id": route.id,
                            "route_title": route.title
                        ])
                    })
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Route row

private struct MapRouteRow: View {
    let route: TourRoute

    var body: some View {
        HStack(spacing: 12) {
            PlaceThumbnail(url: route.thumbnailURL,
                           category: .landmark,
                           thumbnailPixelSize: CGSize(width: 200, height: 200))
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(route.stopsCount) stops · \(route.duration.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}
