import SwiftUI

/// The Map tab.
///
/// The old version stacked a search field, a filter icon and a pair of +/− zoom
/// buttons over the map, and drove the place card with a hand-written drag gesture.
/// Zoom buttons went out with pinch gestures; the card is a system sheet with
/// detents now, and the filters live on the map as chips instead of behind an icon.
struct MapScreenView: View {
    @StateObject private var vm = MapViewModel()

    @State private var searchText = ""
    @State private var selectedPlace: Place?
    @State private var recenterTrigger = 0
    @State private var focusTrigger = 0
    @State private var zoomInTrigger = 0
    @State private var zoomOutTrigger = 0
    @State private var searchDebounce: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            MapboxMapView(
                places: vm.filteredPlaces,
                onPinTapped: { place in
                    Analytics.track(.mapPinTapped, [
                        "place_id": place.id,
                        "place_name": place.name,
                        "category": place.category.displayName,
                        "rating": place.rating
                    ])
                    selectedPlace = place
                },
                recenterTrigger: recenterTrigger,
                focusTrigger: focusTrigger,
                zoomInTrigger: zoomInTrigger,
                zoomOutTrigger: zoomOutTrigger
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                searchField
                categoryChips
                if !searchText.isEmpty && vm.filteredPlaces.isEmpty {
                    Text("Nothing matches \"\(searchText)\"")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .padding(.top, 6)
        }
        .overlay(alignment: .bottomTrailing) { mapControls }
        .sheet(item: $selectedPlace) { place in
            PlaceSheet(place: place)
                .presentationDetents([.height(210), .medium, .large])
                .presentationDragIndicator(.visible)
                // Half-open the card and the map underneath still pans — the whole
                // point of looking at a place on a map.
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        // The map runs edge to edge, so the translucent tab bar shows street labels
        // through itself. Give it a solid background on this tab only.
        .toolbarBackground(.visible, for: .tabBar)
        .trackScreen("Map")
        .onAppear { vm.loadPlaces() }
    }

    // MARK: - Controls

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)

            TextField("Search places", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, query in
                    vm.searchQuery = query
                    // Debounced so we log one search per query, not one per keystroke.
                    searchDebounce?.cancel()
                    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    searchDebounce = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard !Task.isCancelled else { return }
                        // Take the camera to the matches — filtering pins the user
                        // cannot see is indistinguishable from finding nothing.
                        focusTrigger += 1
                        Analytics.track(.mapSearched, [
                            "query": query,
                            "results_count": vm.filteredPlaces.count
                        ])
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    /// One tap narrows the map to a category, one tap comes back. A filter you can
    /// see is used; a filter behind an icon is not.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", icon: "mappin.and.ellipse", tint: .primary, isOn: vm.showsEverything) {
                    vm.selectedCategories = Set(PlaceCategory.allCases)
                    Analytics.track(.mapFiltersApplied, ["category": "all"])
                }

                ForEach(vm.availableCategories, id: \.self) { category in
                    chip(title: category.displayName,
                         icon: category.icon,
                         tint: Color(category.color),
                         isOn: vm.isolated(category)) {
                        vm.toggleIsolated(category)
                        Analytics.track(.mapFiltersApplied, [
                            "category": category.displayName,
                            "selected_count": vm.selectedCategories.count
                        ])
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: String,
                      icon: String,
                      tint: Color,
                      isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(isOn ? Color.white : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isOn {
                        Capsule().fill(tint == .primary ? Color.blue : tint)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            // Temporary: pinch-zooming in the Simulator is awkward, so the map keeps
            // explicit zoom buttons during development. Listed in PRE-RELEASE.md —
            // real phones have fingers, these go before the App Store.
            VStack(spacing: 1) {
                zoomButton("plus") { zoomInTrigger += 1 }
                Divider().frame(width: 44)
                zoomButton("minus") { zoomOutTrigger += 1 }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

            locateButton
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }

    private func zoomButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var locateButton: some View {
        Button {
            recenterTrigger += 1
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapScreenView()
}
