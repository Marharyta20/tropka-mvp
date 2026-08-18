import PhotosUI
import SDWebImageSwiftUI
import SwiftUI

// MARK: - Mode

enum RouteEditorMode: Equatable {
    case create
    case edit(routeID: String)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var routeID: String? {
        if case let .edit(id) = self { return id }
        return nil
    }
}

// MARK: - RouteEditorView

/// Build a route out of curated places, with a per-stop time estimate and note.
struct RouteEditorView: View {

    let mode: RouteEditorMode
    /// Called after a successful save so the caller can refresh its list.
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var draftStore = RouteDraftStore.shared

    @State private var title = ""
    @State private var routeDescription = ""
    @State private var status: RouteStatus = .draft
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var stops: [DraftStop] = []

    @State private var thumbnailImage: UIImage?
    @State private var thumbnailURL: URL?
    @State private var photoItem: PhotosPickerItem?

    @State private var showPicker = false
    @State private var editingStop: DraftStop?

    @State private var isLoading = false
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var totalMinutes: Int { stops.reduce(0) { $0 + max(0, $1.timeSpent) } }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !stops.isEmpty
            && !isSaving
            && !isUploading
    }

    var body: some View {
        Form {
            detailsSection
            visibilitySection
            coverSection
            stopsSection
        }
        .navigationTitle(mode.isEdit ? "Edit route" : "New route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .bold()
                        .disabled(!canSave)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if !stops.isEmpty { EditButton() }
            }
        }
        .overlay {
            if isLoading {
                ProgressView().controlSize(.large)
            }
        }
        .sheet(isPresented: $showPicker) {
            PlacePickerView(alreadyAdded: Set(stops.map(\.placeID))) { place in
                toggle(place)
            }
        }
        .sheet(item: $editingStop) { stop in
            StopDetailEditor(stop: stop) { updated in
                if let idx = stops.firstIndex(where: { $0.id == updated.id }) {
                    stops[idx] = updated
                }
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await load() }
        .trackScreen("RouteEditor", ["mode": mode.isEdit ? "edit" : "create"])
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Title", text: $title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $routeDescription)
                    .frame(minHeight: 110)
            }

            HStack {
                TextField("Add tag", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag).font(.caption)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Route")
        } footer: {
            Text("The description sits behind the About button on the route screen, "
                 + "so it can be as long as it needs to be.")
        }
    }

    private var visibilitySection: some View {
        Section {
            Picker("Visibility", selection: $status) {
                ForEach(RouteStatus.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Visibility")
        } footer: {
            Text(status.explanation)
        }
    }

    private var coverSection: some View {
        Section("Cover") {
            HStack(spacing: 12) {
                Group {
                    if let thumbnailImage {
                        Image(uiImage: thumbnailImage).resizable().scaledToFill()
                    } else if let thumbnailURL {
                        WebImage(url: thumbnailURL) { $0.resizable().scaledToFill() }
                            placeholder: { Color(.systemGray5) }
                    } else {
                        Color(.systemGray5)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(thumbnailURL == nil ? "Choose image" : "Replace image")
                    }
                    if isUploading {
                        ProgressView("Uploading…").font(.caption)
                    }
                }
                Spacer()
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private var stopsSection: some View {
        Section {
            if stops.isEmpty {
                Text("No stops yet. Add places to build the route.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    Button { editingStop = stop } label: {
                        StopRowContent(stop: stop, index: index + 1)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { stops.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { stops.remove(atOffsets: $0) }
            }

            Button {
                showPicker = true
            } label: {
                Label("Add stops", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("Stops")
                Spacer()
                if !stops.isEmpty {
                    Text("\(stops.count) · \(totalMinutes.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if !stops.isEmpty {
                Text("Tap a stop to set how long to spend there and add a note. Drag to reorder.")
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let t = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty,
              !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame })
        else { return }
        tags.append(t)
        newTag = ""
    }

    private func toggle(_ place: PlacePick) {
        if let idx = stops.firstIndex(where: { $0.placeID == place.id }) {
            stops.remove(at: idx)
        } else {
            stops.append(DraftStop(placeID: place.id,
                                   name: place.name,
                                   photoURL: place.photoURL))
            Analytics.track(.routeStopAdded, ["place_id": place.id, "source": "picker"])
        }
    }

    private func load() async {
        switch mode {
        case .create:
            // Pick up anything collected from the map before the editor was opened.
            guard stops.isEmpty else { return }
            stops = draftStore.drain()

        case let .edit(routeID):
            guard stops.isEmpty, title.isEmpty else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let loaded = try await RouteEditorService().fetchForEditing(routeID: routeID)
                title = loaded.title
                routeDescription = loaded.description ?? ""
                status = loaded.status
                tags = loaded.tags
                thumbnailURL = loaded.thumbnailURL
                stops = loaded.stops
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            thumbnailImage = UIImage(data: data)
            thumbnailURL = try await StorageService.shared.uploadRouteThumbnail(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = routeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = RouteEditorService()

        do {
            var properties: [String: Any] = [
                "stops_count": stops.count,
                "total_minutes": totalMinutes,
                "tags_count": tags.count,
                "has_cover": thumbnailURL != nil,
                "has_description": !cleanDescription.isEmpty,
                "status": status.rawValue
            ]

            switch mode {
            case .create:
                let id = try await service.createRoute(title: cleanTitle,
                                                       description: cleanDescription.isEmpty ? nil : cleanDescription,
                                                       status: status,
                                                       tags: tags,
                                                       thumbnailURL: thumbnailURL,
                                                       stops: stops)
                properties["route_id"] = id
                Analytics.track(.routeCreated, properties)

            case let .edit(routeID):
                try await service.updateRoute(routeID: routeID,
                                              title: cleanTitle,
                                              description: cleanDescription.isEmpty ? nil : cleanDescription,
                                              status: status,
                                              tags: tags,
                                              thumbnailURL: thumbnailURL,
                                              stops: stops)
                properties["route_id"] = routeID
                Analytics.track(.routeUpdated, properties)
            }

            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Stop row

private struct StopRowContent: View {
    let stop: DraftStop
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue)
                Text("\(index)").font(.caption.bold()).foregroundColor(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).lineLimit(1)
                Text(stop.notes.isEmpty
                     ? "≈ \(stop.timeSpent) min"
                     : "≈ \(stop.timeSpent) min · \(stop.notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Per-stop editor

private struct StopDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DraftStop
    let onSave: (DraftStop) -> Void

    init(stop: DraftStop, onSave: @escaping (DraftStop) -> Void) {
        _draft = State(initialValue: stop)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time here") {
                    Stepper(value: $draft.timeSpent, in: 0...480, step: 5) {
                        Text("\(draft.timeSpent) min")
                    }
                }
                Section("Your note") {
                    TextEditor(text: $draft.notes)
                        .frame(height: 120)
                }
            }
            .navigationTitle(draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(draft); dismiss() }.bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
