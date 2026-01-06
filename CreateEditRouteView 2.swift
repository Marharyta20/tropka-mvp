import SwiftUI
import CoreLocation
import MapboxMaps

struct CreateEditRouteView: View {
    enum Mode { case create, edit(routeID: String) }

    let mode: Mode

    @State private var title: String = ""
    @State private var stops: [Stop] = []
    @State private var showSearch = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Map bindings for MapRepresentable
    @State private var mapView: MapView?
    @State private var pinManager: PointAnnotationManager?
    @State private var lineManager: PolylineAnnotationManager?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Route title", text: $title)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)

                // Map preview of current stops
                ZStack {
                    MapRepresentable(
                        mapView: $mapView,
                        pinManager: $pinManager,
                        lineManager: $lineManager,
                        stops: stops,
                        routeCoords: []
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    if stops.isEmpty {
                        Text("No stops yet. Add some via Search.")
                            .foregroundColor(.secondary)
                    }
                }

                // Stops list with reordering
                List {
                    ForEach(stops) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.name).font(.body)
                            if let notes = s.notes, !notes.isEmpty {
                                Text(notes).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in stops.remove(atOffsets: idx); renumberStops() }
                    .onMove { from, to in stops.move(fromOffsets: from, toOffset: to); renumberStops() }
                }
                .frame(maxHeight: 260)

                HStack {
                    Button {
                        showSearch = true
                    } label: {
                        Label("Add stop", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button(action: saveRoute) {
                        if isSaving { ProgressView() } else { Text(modeTitle) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stops.isEmpty || isSaving)
                }
                .padding(.horizontal)

                if let msg = errorMessage {
                    Text(msg).foregroundColor(.red).font(.footnote).padding(.horizontal)
                }

                Spacer(minLength: 8)
            }
            .navigationTitle(mode == .create ? "New Route" : "Edit Route")
            .toolbar { EditButton() }
            .sheet(isPresented: $showSearch) {
                PlaceSearchView(onSelect: { result in
                    addStop(from: result)
                })
            }
            .onAppear { if case let .edit(id) = mode { Task { await loadRoute(id) } } }
        }
    }

    private var modeTitle: String { mode == .create ? "Create" : "Save" }

    private func renumberStops() {
        stops = stops.enumerated().map { idx, s in
            var copy = s
            copy.orderIndex = idx + 1
            return copy
        }
    }

    private func addStop(from result: MapboxSearchResult) {
        // Minimal Stop construction; assumes Stop has this initializer in your project.
        let geo = GeoPoint(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude)
        let new = Stop(
            id: UUID().uuidString,
            name: result.name,
            coordinates: geo,
            orderIndex: (stops.last?.orderIndex ?? 0) + 1,
            timeSpent: 15,
            photoURL: nil,
            notes: result.subtitle
        )
        stops.append(new)
    }

    private func saveRoute() {
        // Placeholder: integrate with your Firestore create/update logic.
        // For now, just fake a save and clear error.
        isSaving = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isSaving = false
        }
    }

    private func loadRoute(_ id: String) async {
        // Placeholder for loading existing route into editor; integrate with Firestore.
    }
}

#Preview {
    CreateEditRouteView(mode: .create)
}
