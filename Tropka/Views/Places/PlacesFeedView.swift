import SDWebImageSwiftUI
import SwiftUI

// MARK: - View model

@MainActor
final class PlacesFeedViewModel: ObservableObject {
    @Published var places: [PlaceDetails] = []
    @Published var query = ""
    @Published var categories: Set<PlaceCategory> = []
    @Published var sort: PlaceSort = .rating
    /// Applied to what is already loaded, not to the query — opening hours live in
    /// a JSON blob that Postgres can't filter on cheaply.
    @Published var openNowOnly = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    /// False until the first page has come back, so the feed does not claim
    /// "Nothing matches" before it has asked for anything.
    @Published private(set) var hasLoaded = false

    private var offset = 0
    private var reachedEnd = false
    private let pageSize = 30
    /// Bumped by every reload. A page that arrives after the query changed belongs
    /// to the old query and is dropped instead of being appended into a list that
    /// has already been cleared.
    private var generation = 0

    var visible: [PlaceDetails] {
        openNowOnly ? places.filter { $0.isOpenNow == true } : places
    }

    func reload() async {
        generation += 1
        // Any page still in flight belongs to the previous query. Releasing the
        // flag here is what lets the new query start immediately; the stale page
        // is discarded by the generation check below rather than appended into a
        // list that has just been emptied.
        isLoading = false
        offset = 0
        reachedEnd = false
        places = []
        await load(generation: generation)
    }

    func loadMore() async {
        guard !isLoading, !reachedEnd else { return }
        await load(generation: generation)
    }

    private func load(generation gen: Int) async {
        isLoading = true
        // `return` is not allowed inside a defer block, hence the plain if.
        defer {
            if gen == generation {
                isLoading = false
                hasLoaded = true
            }
        }

        do {
            let page = try await PlacesService.shared.feed(
                query: query,
                categories: categories,
                sort: sort,
                offset: offset,
                pageSize: pageSize
            )
            guard gen == generation else { return }
            places.append(contentsOf: page)
            offset += page.count
            reachedEnd = page.count < pageSize
            errorMessage = nil
        } catch {
            guard gen == generation else { return }
            errorMessage = error.localizedDescription
            // Deliberately not setting `reachedEnd`: one timeout used to disable
            // pagination for the rest of the session, with no way back except a
            // pull to refresh the user had no reason to try.
        }
    }

    func loadMoreIfNeeded(current place: PlaceDetails) async {
        // Keyed off `visible`, not `places`. With "Open now" on, the last loaded
        // place is usually filtered out of the list, so the row that would have
        // asked for the next page was never rendered and scrolling stopped dead.
        guard let last = visible.last, last.id == place.id else { return }
        await loadMore()
    }
}

// MARK: - Feed

struct PlacesFeedView: View {
    /// Owned by ExploreView so that switching segments keeps the loaded pages
    /// and the scroll position instead of starting over.
    @ObservedObject var vm: PlacesFeedViewModel
    @State private var searchDebounce: Task<Void, Never>?
    @State private var showFilters = false

    var body: some View {
        VStack(spacing: 6) {
            filterRow

            if let errorMessage = vm.errorMessage, vm.places.isEmpty {
                ContentUnavailableView("Couldn't load places",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(errorMessage))
            } else if !vm.hasLoaded || (vm.isLoading && vm.places.isEmpty) {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.visible.isEmpty {
                ContentUnavailableView {
                    Label("Nothing matches", systemImage: "magnifyingglass")
                } description: {
                    Text(vm.openNowOnly
                         ? "Nothing loaded so far is open right now."
                         : "Try a different name or fewer filters.")
                } actions: {
                    // The filter runs over loaded pages, so "nothing open" can simply
                    // mean "not far enough down the list yet".
                    if vm.openNowOnly {
                        Button("Load more places") { Task { await vm.loadMore() } }
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                list
            }
        }
        .sheet(isPresented: $showFilters) {
            PlaceFiltersSheet(selected: $vm.categories)
        }
        .onChange(of: vm.query) { _, _ in scheduleReload() }
        .onChange(of: vm.sort) { _, _ in Task { await vm.reload() } }
        .onChange(of: vm.categories) { _, _ in Task { await vm.reload() } }
        .task { if vm.places.isEmpty { await vm.reload() } }
    }

    // MARK: Pieces

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Sort", selection: $vm.sort) {
                        ForEach(PlaceSort.allCases) { option in
                            Label(option.title, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    Label(vm.sort.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    showFilters = true
                } label: {
                    Label(vm.categories.isEmpty ? "Category" : "\(vm.categories.count) selected",
                          systemImage: "line.3.horizontal.decrease")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Toggle(isOn: $vm.openNowOnly) {
                    Label("Open now", systemImage: "clock")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)

                if !vm.categories.isEmpty {
                    Button("Clear") { vm.categories = [] }
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(vm.visible) { place in
                    NavigationLink {
                        PlaceDetailView(placeID: place.id, preloaded: place)
                    } label: {
                        PlaceCard(place: place)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.placeOpened, [
                            "place_id": place.id,
                            "place_name": place.name,
                            "category": place.category.displayName,
                            "source": "places_feed"
                        ])
                    })
                    .task { await vm.loadMoreIfNeeded(current: place) }
                }

                if vm.isLoading {
                    ProgressView().padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await vm.reload() }
    }

    private func scheduleReload() {
        searchDebounce?.cancel()
        let text = vm.query
        searchDebounce = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await vm.reload()
            if !text.isEmpty {
                Analytics.track(.placesSearched, ["query": text, "results_count": vm.places.count])
            }
        }
    }
}

// MARK: - Card

struct PlaceCard: View {
    let place: PlaceDetails

    var body: some View {
        HStack(spacing: 12) {
            PlaceThumbnail(url: place.photoURL,
                           category: place.category,
                           thumbnailPixelSize: CGSize(width: 320, height: 320))
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Score only in a dense list. The review count earns its place
                    // on the detail screen and the map card, where it is a link into
                    // Google's reviews rather than a number with nowhere to go.
                    if place.rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2).foregroundColor(.yellow)
                            Text(String(format: "%.1f", place.rating)).font(.caption)
                        }
                    }
                    if let price = place.priceRange {
                        Text("· \(price)").font(.caption2).foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Label(place.category.displayName, systemImage: place.category.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let isOpen = place.isOpenNow {
                        Text(isOpen ? "Open" : "Closed")
                            .font(.caption2.bold())
                            .foregroundColor(isOpen ? .green : .red)
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }
}

// MARK: - Filters

private struct PlaceFiltersSheet: View {
    @Binding var selected: Set<PlaceCategory>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        Button {
                            if selected.contains(category) {
                                selected.remove(category)
                            } else {
                                selected.insert(category)
                            }
                        } label: {
                            HStack {
                                Label(category.displayName, systemImage: category.icon)
                                    .foregroundColor(Color(category.color))
                                Spacer()
                                if selected.contains(category) {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Nothing selected means every category.")
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { selected = [] }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }
}
