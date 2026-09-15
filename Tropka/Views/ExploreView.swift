import CoreLocation
import SDWebImageSwiftUI
import SwiftUI

struct ExploreView: View {

    /// Where "All places" and a category tile both lead: the full catalogue,
    /// pushed rather than switched to. The title is the only thing that differs,
    /// and it doubles as the identity — two pushes of the same list would be the
    /// same screen anyway.
    private struct CatalogueRoute: Identifiable, Hashable {
        let title: String
        var id: String { title }
    }

    @StateObject private var vm = ExploreViewModel()
    @StateObject private var placesVM = PlacesFeedViewModel()

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var searchDebounce: Task<Void, Never>?
    @State private var placeSearchDebounce: Task<Void, Never>?
    @State private var showNewRoute = false
    @State private var categoryCounts: [CategoryCount] = []
    @State private var catalogue: CatalogueRoute?

    /// Place results for the home search. A separate, lighter query rather than
    /// `placesVM`: that view model belongs to the pushed catalogue and carries
    /// its category filters, which have nothing to do with what was typed here.
    @State private var placeResults: [PlacePick] = []

    @State private var nearbyPlaces: [PlaceDetails] = []
    @ObservedObject private var location = NearbyLocation.shared
    @ObservedObject private var preferences = UserPreferences.shared

    /// The tiles the user said they care about, first. Ordering only — every
    /// category is still there, because hiding one the user did not ask to hide
    /// makes the catalogue look smaller than it is.
    private var orderedCategoryCounts: [CategoryCount] {
        guard !preferences.interests.isEmpty else { return categoryCounts }
        let picked = Set(preferences.interests)
        return categoryCounts.filter { picked.contains($0.category) }
             + categoryCounts.filter { !picked.contains($0.category) }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Filtered list
    var filteredRoutes: [TourRoute] {
        var result = vm.routes

        // Filter: search
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        // Filter: by tag
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        // Sort: by rating
        result = result.sorted { $0.rating > $1.rating }
        return result
    }

    /// Rotates daily rather than always showing the highest rated one, so the
    /// page has a reason to look different tomorrow. Only routes with a cover
    /// qualify — the hero is mostly photograph.
    private var featuredRoute: TourRoute? {
        let candidates = vm.routes
            .filter { $0.thumbnailURL != nil }
            .sorted { $0.id < $1.id }
        guard !candidates.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return candidates[day % candidates.count]
    }

    /// The place near you, rotated daily.
    ///
    /// Not simply the nearest: that is a lottery won by whatever happens to be
    /// across the street, and it would be the same thing every day for anyone who
    /// opens the app at home. The nearest handful are the candidates and the date
    /// picks among them, so the card has a reason to differ tomorrow while still
    /// being somewhere you could walk to now.
    private var nearbyPick: PlaceDetails? {
        let candidates = Array(nearbyPlaces.prefix(8))
        guard !candidates.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return candidates[day % candidates.count]
    }

    private var nearbyPickDistance: Double? {
        guard let pick = nearbyPick,
              let here = location.coordinate,
              let lat = pick.lat, let lng = pick.lng else { return nil }
        let dLat = (lat - here.latitude) * 111_320
        let dLng = (lng - here.longitude) * 111_320 * cos(here.latitude * .pi / 180)
        return (dLat * dLat + dLng * dLng).squareRoot()
    }

    private var totalPlaceCount: Int {
        categoryCounts.reduce(0) { $0 + $1.count }
    }

    // Every tag present in the loaded routes
    var allTags: [String] {
        Set(vm.routes.flatMap { $0.tags }).sorted()
    }

    var body: some View {
        NavigationStack {
            home
            // Inline, so the bar stays one row: the name and the "+" sit in it
            // together and the search field keeps the space a large title would
            // have taken.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                brandMark

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Analytics.track(.routeEditorOpened, [
                            "mode": "create",
                            "source": Analytics.Source.explore.rawValue,
                            "draft_size": RouteDraftStore.shared.count
                        ])
                        showNewRoute = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // One field, searching both. There is no longer a control on screen
            // saying which half you are in, so it cannot search only one of them.
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search routes and places")
            .navigationDestination(isPresented: $showNewRoute) {
                RouteEditorView(mode: .create) {
                    vm.loadRoutes()
                }
            }
            .navigationDestination(item: $catalogue) { route in
                PlacesFeedView(vm: placesVM)
                    .navigationTitle(route.title)
                    .navigationBarTitleDisplayMode(.inline)
                    // Its own field: the catalogue is a screen of its own now,
                    // and the home search behind it has already been left behind.
                    .searchable(text: $placesVM.query,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search places")
            }
        }
        .trackScreen("Explore")
        .onChange(of: searchText) { _, newValue in
            scheduleRouteSearchEvent(newValue)
            schedulePlaceSearch(newValue)
        }
        .task {
            if vm.routes.isEmpty { vm.loadRoutes() }
            if categoryCounts.isEmpty {
                categoryCounts = (try? await PlacesService.shared.categoryCounts()) ?? []
            }
            location.refreshIfNeeded()
            // Both halves are needed. `onChange` covers the first fix of the
            // session; this covers every visit after it, when the coordinate is
            // already known and nothing is going to change.
            if nearbyPlaces.isEmpty { await loadNearby() }
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            Task { await loadNearby() }
        }
    }

    // MARK: - Brand mark

    /// The name, rather than a navigation title.
    ///
    /// A large title would be the system font in the system colour and would
    /// collapse away on the first scroll — and the slot was empty anyway since
    /// the segmented control left it.
    ///
    /// Set in the rounded bold the sign-in screen uses for the mark, and in the
    /// same plain text colour it uses there. Not coral: coral is the error colour
    /// in this app. Not blue either, because blue in iOS means "you can tap this"
    /// and the name is not a button.
    ///
    /// Two branches for one reason: iOS 26 draws every toolbar item on a glass
    /// capsule, which around a word rather than a control reads as a button
    /// nobody can press. `sharedBackgroundVisibility` turns it off and does not
    /// exist before 26, where there is no capsule to turn off.
    @ToolbarContentBuilder
    private var brandMark: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { brandMarkLabel }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { brandMarkLabel }
        }
    }

    private var brandMarkLabel: some View {
        Text("Tropka")
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            // The toolbar proposes a width, and at this size the word does not
            // fit it — so SwiftUI did what it does to any text too long for its
            // box and truncated it to "T…". `fixedSize` takes the width the word
            // actually needs.
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    /// Debounced so we log one search per query, not one per keystroke.
    private func scheduleRouteSearchEvent(_ query: String) {
        searchDebounce?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchDebounce = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            Analytics.track(.exploreSearched, [
                "query": query,
                "results_count": filteredRoutes.count
            ])
        }
    }

    /// Debounced too, and for a different reason: this one hits the network on
    /// every keystroke otherwise.
    private func schedulePlaceSearch(_ query: String) {
        placeSearchDebounce?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            placeResults = []
            return
        }
        placeSearchDebounce = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let found = (try? await PlacesService.shared.search(query: trimmed, limit: 12)) ?? []
            guard !Task.isCancelled else { return }
            placeResults = found
        }
    }

    private func loadNearby() async {
        guard let here = location.coordinate else { return }
        nearbyPlaces = (try? await PlacesService.shared.nearby(
            latitude: here.latitude,
            longitude: here.longitude
        )) ?? []
    }

    private func openCatalogue(_ category: PlaceCategory?) {
        Analytics.track(.categoryOpened, [
            "category": category?.displayName ?? "all",
            "source": "explore_home"
        ])
        // The pushed list is a screen of its own, with its own search. Carrying
        // the home query into it would silently filter a catalogue the user
        // opened to browse.
        placesVM.categories = category.map { [$0] } ?? []
        placesVM.query = ""
        catalogue = CatalogueRoute(title: category?.displayName ?? "All places")
    }

    // MARK: - Routes

    @ViewBuilder
    private var home: some View {
        if vm.isLoading && vm.routes.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let msg = vm.errorMessage {
            ExploreErrorBlock(message: msg) { vm.loadRoutes() }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // While searching the page becomes a result list — the two
                    // hero cards and the category row would only be in the way.
                    if !isSearching, selectedTag == nil {
                        featuredSection
                        nearbySection
                        categoriesSection
                    }

                    routesListSection

                    if isSearching {
                        placeResultsSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                Analytics.track(.exploreRefreshed)
                vm.loadRoutes()
                await loadNearby()
            }
        }
    }

    @ViewBuilder
    private var featuredSection: some View {
        if let featured = featuredRoute {
            NavigationLink {
                TourDetailsView(route: featured, source: .explore)
            } label: {
                FeaturedRouteCard(route: featured)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                Analytics.track(.routeOpened, [
                    "route_id": featured.id,
                    "route_title": featured.title,
                    "source": "explore_featured"
                ])
            })
            .padding(.horizontal, 16)
        }
    }

    /// Absent rather than empty when there is no location or nothing is close.
    /// A "near you" card that says "we don't know where you are" is worse than
    /// the space it would occupy.
    @ViewBuilder
    private var nearbySection: some View {
        if let pick = nearbyPick {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Place of the day",
                              subtitle: "Worth a detour from where you are")
                    .padding(.horizontal, 16)

                NavigationLink {
                    PlaceDetailView(placeID: pick.id, preloaded: pick)
                } label: {
                    NearbyPlaceCard(place: pick, metresAway: nearbyPickDistance)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.placeOpened, [
                        "place_id": pick.id,
                        "place_name": pick.name,
                        "source": "explore_place_of_the_day"
                    ])
                })
                .padding(.horizontal, 16)
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Browse places",
                          subtitle: "Everything the guide knows about the city")
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // First, and before any category: the catalogue as a whole
                    // used to be reachable only through the segmented control
                    // that this screen no longer has.
                    AllPlacesTile(count: totalPlaceCount) {
                        openCatalogue(nil)
                    }

                    ForEach(orderedCategoryCounts) { item in
                        CategoryTile(category: item.category, count: item.count) {
                            openCatalogue(item.category)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var routesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: isSearching ? "Routes" : "All routes")
                .padding(.horizontal, 16)

            if !isSearching {
                tagRow
            }

            LazyVStack(spacing: 20) {
                ForEach(listedRoutes) { r in
                    NavigationLink(destination: TourDetailsView(route: r, source: .explore)) {
                        ExploreCard(route: r)
                            .overlay(alignment: .topLeading) {
                                if isSearching {
                                    ResultKindBadge(isRoute: true).padding(10)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.routeOpened, [
                            "route_id": r.id,
                            "route_title": r.title,
                            "source": Analytics.Source.explore.rawValue,
                            "rating": r.rating,
                            "stops_count": r.stopsCount,
                            "has_search": !searchText.isEmpty,
                            "has_tag_filter": selectedTag != nil
                        ])
                    })
                }

                if listedRoutes.isEmpty {
                    Text(isSearching ? "No routes match your search." : "No routes yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isSearching ? 12 : 40)
                }
            }
            .padding(.horizontal, 16)
            .animation(.default, value: listedRoutes)
        }
    }

    // MARK: - Places in search

    /// The other half of the result list.
    ///
    /// Places are far more numerous than routes, so they go second: putting the
    /// twelve strongest place matches above the two route matches would bury the
    /// thing this app is actually for.
    private var placeResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Places")
                .padding(.horizontal, 16)

            LazyVStack(spacing: 0) {
                ForEach(placeResults) { place in
                    NavigationLink {
                        PlaceDetailView(placeID: place.id)
                    } label: {
                        PlaceResultRow(place: place)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.placeOpened, [
                            "place_id": place.id,
                            "place_name": place.name,
                            "source": "explore_search"
                        ])
                    })

                    Divider().padding(.leading, 74)
                }

                if placeResults.isEmpty {
                    Text("No places match your search.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)

            if !placeResults.isEmpty {
                Button("See the whole catalogue") { openCatalogue(nil) }
                    .font(.footnote)
                    .padding(.horizontal, 16)
            }
        }
    }

    /// The featured route is already on screen; repeating it right below would
    /// make a five-route catalogue look even smaller than it is.
    private var listedRoutes: [TourRoute] {
        guard !isSearching, selectedTag == nil, let featured = featuredRoute else {
            return filteredRoutes
        }
        return filteredRoutes.filter { $0.id != featured.id }
    }

    /// Only the selected chip carries a fill. Filling every chip made the screen
    /// read as a wall of coloured rectangles.
    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(title: "All", isSelected: selectedTag == nil) {
                    Analytics.track(.exploreTagFiltered, ["tag": "all"])
                    selectedTag = nil
                }

                ForEach(allTags, id: \.self) { tag in
                    TagChip(title: tag.capitalized, isSelected: selectedTag == tag) {
                        Analytics.track(.exploreTagFiltered, [
                            "tag": tag,
                            "results_count": vm.routes.filter { $0.tags.contains(tag) }.count
                        ])
                        selectedTag = tag
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Chip

/// A place in the search results: compact, because twelve of these sit under
/// the route cards and each one only has to be recognisable enough to tap.
private struct PlaceResultRow: View {
    let place: PlacePick

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = place.photoURL {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    Color(.systemGray5)
                        .overlay(
                            Image(systemName: place.category.icon)
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let address = place.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            ResultKindBadge(isRoute: false)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Chip

private struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule().fill(Color.blue)
                    } else {
                        Capsule().strokeBorder(Color(.systemGray4), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ExploreErrorBlock: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
