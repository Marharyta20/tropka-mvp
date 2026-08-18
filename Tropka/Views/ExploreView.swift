import SwiftUI

struct ExploreView: View {

    /// Routes are the curated itineraries; Places is the raw catalogue behind them.
    /// The catalogue is by far the larger asset, so it gets equal billing here
    /// rather than being reachable only by panning the map.
    private enum Section: String, CaseIterable, Identifiable {
        case routes, places
        var id: String { rawValue }
        var title: String { self == .routes ? "Routes" : "Places" }
        var searchPrompt: String { self == .routes ? "Search routes" : "Search places" }
    }

    @StateObject private var vm = ExploreViewModel()
    @StateObject private var placesVM = PlacesFeedViewModel()

    @State private var section: Section = .routes
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var searchDebounce: Task<Void, Never>?
    @State private var showNewRoute = false
    @State private var categoryCounts: [CategoryCount] = []

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

    // Every tag present in the loaded routes
    var allTags: [String] {
        Set(vm.routes.flatMap { $0.tags }).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .routes: routesSection
                case .places: PlacesFeedView(vm: placesVM)
                }
            }
            // The tab bar already says "Explore", so a large title would only
            // repeat it and cost a whole band of vertical space. The section
            // switch takes that slot instead, which also gives the "+" company
            // in a row it used to occupy alone.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $section) {
                        ForEach(Section.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
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
            // One system search field for both sections — it collapses on scroll,
            // which is what actually buys the vertical space back.
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: section.searchPrompt)
            .navigationDestination(isPresented: $showNewRoute) {
                RouteEditorView(mode: .create) {
                    vm.loadRoutes()
                }
            }
        }
        .trackScreen("Explore")
        .onChange(of: searchText) { _, newValue in
            // Scope semantics: the same query, applied to whichever section is open.
            if section == .places { placesVM.query = newValue }
            scheduleRouteSearchEvent(newValue)
        }
        .onChange(of: section) { _, newValue in
            if newValue == .places { placesVM.query = searchText }
            Analytics.track(.exploreSectionSwitched, ["section": newValue.rawValue])
        }
        .task {
            if vm.routes.isEmpty { vm.loadRoutes() }
            if categoryCounts.isEmpty {
                categoryCounts = (try? await PlacesService.shared.categoryCounts()) ?? []
            }
        }
    }

    /// Debounced so we log one search per query, not one per keystroke.
    private func scheduleRouteSearchEvent(_ query: String) {
        guard section == .routes else { return }
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

    private func openCategory(_ category: PlaceCategory) {
        Analytics.track(.categoryOpened, [
            "category": category.displayName,
            "source": "explore_home"
        ])
        placesVM.categories = [category]
        placesVM.query = searchText
        section = .places
    }

    // MARK: - Routes

    @ViewBuilder
    private var routesSection: some View {
        if vm.isLoading && vm.routes.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let msg = vm.errorMessage {
            ErrorBlock(message: msg) { vm.loadRoutes() }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // While searching the page becomes a result list — the hero
                    // and the category row would only be in the way.
                    if !isSearching, selectedTag == nil {
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

                        categoriesSection
                    }

                    routesListSection
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                Analytics.track(.exploreRefreshed)
                vm.loadRoutes()
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
                    ForEach(categoryCounts) { item in
                        CategoryTile(category: item.category, count: item.count) {
                            openCategory(item.category)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var routesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isSearching {
                SectionHeader(title: "All routes")
                    .padding(.horizontal, 16)
            }

            tagRow

            LazyVStack(spacing: 20) {
                ForEach(listedRoutes) { r in
                    NavigationLink(destination: TourDetailsView(route: r, source: .explore)) {
                        ExploreCard(route: r)
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
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .animation(.default, value: listedRoutes)
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

private struct ErrorBlock: View {
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
