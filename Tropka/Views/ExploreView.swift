import SwiftUI

struct ExploreView: View {
    @StateObject private var vm = ExploreViewModel()
    
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var searchDebounce: Task<Void, Never>?
    @State private var showNewRoute = false

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
    
    // Every tag present in the loaded routes
    var allTags: [String] {
        Set(vm.routes.flatMap { $0.tags }).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // ——— Search bar
                TextField("Search by route name", text: $searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    // Debounced so we log one search per query, not one per keystroke.
                    .onChange(of: searchText) { _, newValue in
                        searchDebounce?.cancel()
                        guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        searchDebounce = Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            guard !Task.isCancelled else { return }
                            Analytics.track(.exploreSearched, [
                                "query": newValue,
                                "results_count": filteredRoutes.count
                            ])
                        }
                    }
                
                // ——— Tag filter row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("All") {
                            Analytics.track(.exploreTagFiltered, ["tag": "all"])
                            selectedTag = nil
                        }
                        .font(.caption)
                        .foregroundColor(selectedTag == nil ? .white : .blue)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedTag == nil ? Color.blue : Color(.systemGray5))
                        .clipShape(Capsule())
                        
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag.capitalized) {
                                Analytics.track(.exploreTagFiltered, [
                                    "tag": tag,
                                    "results_count": vm.routes.filter { $0.tags.contains(tag) }.count
                                ])
                                selectedTag = tag
                            }
                            .font(.caption)
                            .foregroundColor(selectedTag == tag ? .white : .blue)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedTag == tag ? Color.blue : Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // ——— Main list
                Group {
                    if vm.isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    else if let msg = vm.errorMessage {
                        ErrorBlock(message: msg) { vm.loadRoutes() }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                ForEach(filteredRoutes) { r in
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
                                
                                if filteredRoutes.isEmpty {
                                    Text("No routes found.")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 50)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            Analytics.track(.exploreRefreshed)
                            vm.loadRoutes()
                        }
                    }
                }
                .animation(.default, value: filteredRoutes)
            }
            .navigationTitle("Explore")
            .toolbar {
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
            .navigationDestination(isPresented: $showNewRoute) {
                RouteEditorView(mode: .create) {
                    vm.loadRoutes()
                }
            }
        }
        .trackScreen("Explore")
        .onAppear {
            if vm.routes.isEmpty { vm.loadRoutes() }
        }
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
