import SDWebImageSwiftUI
import SwiftUI

/// Asks where a place should go: into the draft for a brand-new route, or straight
/// into one of the routes the user already wrote.
///
/// Appending to an existing route writes to the database immediately — there is no
/// "save" step here, which is why each row reports its own result inline.
struct AddToRoutePicker: View {

    let placeID: Int
    let placeName: String
    let placePhotoURL: URL?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var draftStore = RouteDraftStore.shared

    @State private var routes: [TourRoute] = []
    @State private var isLoading = true
    @State private var busyRouteID: String?
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                draftSection
                existingSection
            }
            .navigationTitle("Add to route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .overlay {
                if isLoading && routes.isEmpty {
                    ProgressView()
                }
            }
            .alert("Couldn't add the stop",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadRoutes() }
        }
    }

    // MARK: - Sections

    private var draftSection: some View {
        Section {
            Button {
                toggleDraft()
            } label: {
                HStack {
                    Image(systemName: isInDraft ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isInDraft ? .green : .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New route")
                            .foregroundColor(.primary)
                        Text(draftSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Start something new")
        } footer: {
            Text("Collected places wait here until you open the editor from your profile.")
        }
    }

    @ViewBuilder
    private var existingSection: some View {
        Section("Your routes") {
            if routes.isEmpty && !isLoading {
                Text("You haven't created any routes yet")
                    .foregroundColor(.secondary)
            }

            ForEach(routes) { route in
                Button {
                    Task { await append(to: route) }
                } label: {
                    HStack(spacing: 12) {
                        thumbnail(for: route)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.title)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("\(route.stopsCount) stops · \(route.duration.formattedDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 8)

                        if busyRouteID == route.id {
                            ProgressView()
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .disabled(busyRouteID != nil)
            }
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private func thumbnail(for route: TourRoute) -> some View {
        Group {
            if let url = route.thumbnailURL {
                WebImage(url: url) { $0.resizable().scaledToFill() }
                    placeholder: { Color(.systemGray5) }
            } else {
                Color(.systemGray5)
                    .overlay(Image(systemName: "map").foregroundColor(.secondary))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - State

    private var isInDraft: Bool { draftStore.contains(placeID: placeID) }

    private var draftSubtitle: String {
        if isInDraft {
            return "Already in the draft · \(draftStore.count) places"
        }
        return draftStore.isEmpty ? "Start a draft with this place"
                                  : "Draft has \(draftStore.count) places"
    }

    // MARK: - Actions

    private func toggleDraft() {
        if isInDraft {
            draftStore.remove(placeID: placeID)
            show("Removed from the draft")
        } else {
            draftStore.add(placeID: placeID, name: placeName, photoURL: placePhotoURL)
            Analytics.track(.placeAddedToDraft, [
                "place_id": placeID,
                "place_name": placeName,
                "draft_size": draftStore.count
            ])
            show("Added to the draft")
        }
    }

    private func loadRoutes() async {
        defer { isLoading = false }
        guard let uid = supabase.auth.currentUser?.id.uuidString else { return }
        do {
            routes = try await SupabaseService.shared.fetchRoutes(authoredBy: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func append(to route: TourRoute) async {
        busyRouteID = route.id
        defer { busyRouteID = nil }
        do {
            let added = try await RouteEditorService().appendStop(
                to: route.id,
                placeID: placeID,
                photoURL: placePhotoURL
            )
            if added {
                Analytics.track(.routeStopAppended, [
                    "route_id": route.id,
                    "place_id": placeID,
                    "source": "map"
                ])
                show("Added to \(route.title)")
                await loadRoutes()   // refresh the stop count shown in the row
            } else {
                show("Already in \(route.title)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func show(_ text: String) {
        message = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if message == text { message = nil }
        }
    }
}
