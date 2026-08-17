import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (MapboxSearchResult) -> Void
    var proximity: CLLocationCoordinate2D?

    @State private var query = ""
    @State private var suggestions: [SearchBoxSuggestion] = []
    @State private var isLoading = false
    @State private var resolvingID: String?
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    /// Wait this long after the last keystroke before calling /suggest.
    /// A session covers 50 suggests — without debouncing, one typed query
    /// can burn a whole session on its own.
    private let debounce: Duration = .milliseconds(300)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                content
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search places", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    suggestions = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
        .onChange(of: query) { _, newValue in scheduleSearch(for: newValue) }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            centered {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Retry") { scheduleSearch(for: query, immediate: true) }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        } else if query.isEmpty {
            centered {
                Text("Start typing to search")
                    .foregroundColor(.secondary)
            }
        } else if suggestions.isEmpty && !isLoading {
            centered {
                Text("No results for “\(query)”")
                    .foregroundColor(.secondary)
            }
        } else {
            List(suggestions) { suggestion in
                Button {
                    select(suggestion)
                } label: {
                    row(for: suggestion)
                }
                .disabled(resolvingID != nil)
            }
            .listStyle(.plain)
            .overlay(alignment: .top) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }
    }

    private func row(for suggestion: SearchBoxSuggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.name)
                    .font(.body)
                    .foregroundColor(.primary)
                if let subtitle = suggestion.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if resolvingID == suggestion.mapboxID {
                ProgressView()
            } else if let distance = suggestion.distance {
                Text(formatted(distance: distance))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func centered<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    /// Debounced /suggest. Cancelling the in-flight task on every keystroke is
    /// what keeps a single search inside one billable session.
    private func scheduleSearch(for text: String, immediate: Bool = false) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isLoading = false
            errorMessage = nil
            return
        }

        errorMessage = nil
        isLoading = true

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: debounce)
            }
            guard !Task.isCancelled else { return }

            do {
                let results = try await MapboxSearchBoxService.shared.suggest(
                    query: trimmed,
                    proximity: proximity
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    suggestions = results
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    /// Resolves the tapped suggestion to coordinates via /retrieve, then hands
    /// it back to the caller.
    private func select(_ suggestion: SearchBoxSuggestion) {
        searchTask?.cancel()
        resolvingID = suggestion.mapboxID

        Task {
            do {
                let result = try await MapboxSearchBoxService.shared.retrieve(suggestion)
                await MainActor.run {
                    resolvingID = nil
                    onSelect(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    resolvingID = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatted(distance metres: Double) -> String {
        metres < 1000
            ? "\(Int(metres.rounded())) m"
            : String(format: "%.1f km", metres / 1000)
    }
}

#Preview {
    PlaceSearchView(onSelect: { _ in })
}
