import SwiftUI
import SDWebImageSwiftUI

/// Search over the curated `places` table. Multi-select on purpose: building a
/// route means adding several stops in a row, and dismissing after each one
/// would make that tedious.
struct PlacePickerView: View {

    /// Places already in the route — shown as added, and tapping them removes.
    let alreadyAdded: Set<Int>
    let onToggle: (PlacePick) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PlacePick] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && results.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't load places",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(errorMessage))
                } else if results.isEmpty {
                    ContentUnavailableView("Nothing found",
                                           systemImage: "magnifyingglass",
                                           description: Text("Try a different name."))
                } else {
                    List(results) { place in
                        Button { onToggle(place) } label: {
                            PlaceRow(place: place, isAdded: alreadyAdded.contains(place.id))
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add stops")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search places")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .task { await runSearch("") }
        }
    }

    // MARK: - Search

    /// Debounced: one request per pause in typing, not one per character.
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(text)
        }
    }

    private func runSearch(_ text: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await PlacesService.shared.search(query: text)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct PlaceRow: View {
    let place: PlacePick
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = place.photoURL {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: place.category.icon)
                            .foregroundColor(.secondary))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: place.category.icon).font(.caption2)
                    Text(place.category.displayName)
                    if let address = place.address, !address.isEmpty {
                        Text("· \(address)").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundColor(isAdded ? .green : .blue)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
