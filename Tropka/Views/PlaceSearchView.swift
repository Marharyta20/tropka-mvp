import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (MapboxSearchResult) -> Void
    var proximity: CLLocationCoordinate2D?

    @State private var query = ""
    @State private var results: [MapboxSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search places", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await performSearch() } }
                    if !query.isEmpty {
                        Button(action: { query = ""; results = [] }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)

                if isLoading {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = errorMessage {
                    VStack(spacing: 12) {
                        Text(msg).multilineTextAlignment(.center)
                        Button("Retry") { Task { await performSearch() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Text("Start typing to search Mapbox")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { r in
                        Button {
                            onSelect(r)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.name).font(.body)
                                if let sub = r.subtitle { Text(sub).font(.caption).foregroundColor(.secondary) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") { Task { await performSearch() } }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func performSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let arr = try await MapboxSearchService.shared.search(query: text, proximity: proximity)
            await MainActor.run {
                self.results = arr
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    PlaceSearchView(onSelect: { _ in })
}
