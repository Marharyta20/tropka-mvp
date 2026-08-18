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

    private var offset = 0
    private var reachedEnd = false
    private let pageSize = 30

    var visible: [PlaceDetails] {
        openNowOnly ? places.filter { $0.isOpenNow == true } : places
    }

    func reload() async {
        offset = 0
        reachedEnd = false
        places = []
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await PlacesService.shared.feed(
                query: query,
                categories: categories,
                sort: sort,
                offset: offset,
                pageSize: pageSize
            )
            places.append(contentsOf: page)
            offset += page.count
            reachedEnd = page.count < pageSize
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            reachedEnd = true
        }
    }

    func loadMoreIfNeeded(current place: PlaceDetails) async {
        guard let last = places.last, last.id == place.id else { return }
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
            } else if vm.visible.isEmpty && !vm.isLoading {
                ContentUnavailableView("Nothing matches",
                                       systemImage: "magnifyingglass",
                                       description: Text(vm.openNowOnly
                                                         ? "Nothing loaded so far is open right now."
                                                         : "Try a different name or fewer filters."))
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
            Group {
                if let url = place.photoURL {
                    WebImage(url: url,
                             context: [.imageThumbnailPixelSize: CGSize(width: 320, height: 320)]) {
                        $0.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: place.category.icon).foregroundColor(.secondary))
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if place.rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2).foregroundColor(.yellow)
                            Text(String(format: "%.1f", place.rating)).font(.caption)
                            if place.reviewCount > 0 {
                                Text("(\(place.reviewCount))")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
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
