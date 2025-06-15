import SwiftUI

/// Top-level screen that displays a map with nearby places.
struct MapScreenView: View {
    @StateObject private var vm = MapViewModel()
    @State private var searchText = ""
    @State private var selectedPlace: Place?
    @State private var bottomSheetHeight: CGFloat = 0
    @State private var showFilters = false

    private let minBottomSheetHeight: CGFloat = 120
    private let maxBottomSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.7

    var body: some View {
        ZStack(alignment: .bottom) {
            MapboxMapView(
                places: vm.filteredPlaces,
                onPinTapped: { place in
                    selectedPlace = place
                    bottomSheetHeight = minBottomSheetHeight
                }
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                searchBar
                    .padding(.top, 50)
                Spacer()
            }

            zoomControls
                .padding(.trailing, 16)
                .padding(.bottom, controlsBottomPadding)

            if selectedPlace != nil {
                PlaceBottomSheet(
                    place: $selectedPlace,
                    height: $bottomSheetHeight,
                    minHeight: minBottomSheetHeight,
                    maxHeight: maxBottomSheetHeight
                )
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: bottomSheetHeight)
            }
        }
        .sheet(isPresented: $showFilters) {
            MapFiltersView(selectedCategories: $vm.selectedCategories)
        }
        .onAppear { vm.loadPlaces() }
    }

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search places...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) {
                        vm.searchQuery = searchText
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .cornerRadius(10)

            Button(action: { showFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }

    private var zoomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Button(action: {
                        NotificationCenter.default.post(name: .zoomIn, object: nil)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        NotificationCenter.default.post(name: .zoomOut, object: nil)
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var controlsBottomPadding: CGFloat {
        guard selectedPlace != nil else { return 100 }
        return maxBottomSheetHeight - bottomSheetHeight + 20
    }
}

#Preview {
    MapScreenView()
}
