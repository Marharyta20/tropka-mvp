import SDWebImageSwiftUI
import SwiftUI

/// The Tips tab: short editorial stories that end in real catalogue entries.
/// The card advertises that payoff — "3 pages · 5 places" — so a tip reads as a
/// shortcut into the city, not as a blog post.
struct TipsView: View {

    @StateObject private var vm = TipsViewModel()
    @State private var selectedTip: Tip?
    @State private var searchText = ""

    private var visibleTips: [Tip] {
        guard !searchText.isEmpty else { return vm.tips }
        return vm.tips.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let errorMessage = vm.errorMessage, vm.tips.isEmpty {
                    ContentUnavailableView("Couldn't load tips",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(errorMessage))
                } else if visibleTips.isEmpty && !vm.isLoading {
                    ContentUnavailableView("Nothing found",
                                           systemImage: "magnifyingglass",
                                           description: Text("Try a different word."))
                } else {
                    list
                }
            }
            .navigationTitle("Tips")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable { await vm.reload() }
            .task { if vm.tips.isEmpty { await vm.reload() } }
            .sheet(item: $selectedTip) { TipDetailView(tip: $0) }
        }
        .trackScreen("Tips")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(visibleTips) { tip in
                    Button {
                        Analytics.track(.tipOpened, [
                            "tip_id": tip.id,
                            "tip_title": tip.title,
                            "page_count": tip.pages.count,
                            "place_count": tip.placeCount
                        ])
                        selectedTip = tip
                    } label: {
                        TipCard(tip: tip)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if tip == vm.tips.last { Task { await vm.fetchMore() } }
                    }
                }

                if vm.isLoading || vm.isLoadingMore {
                    ProgressView().padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Card

private struct TipCard: View {
    let tip: Tip

    private var subtitle: String {
        let pages = "\(tip.pages.count) \(tip.pages.count == 1 ? "page" : "pages")"
        guard tip.placeCount > 0 else { return pages }
        return "\(pages) · \(tip.placeCount) places to open"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let url = URL(string: tip.bannerURL), !tip.bannerURL.isEmpty {
                    WebImage(url: url) { $0.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    LinearGradient(colors: [.orange.opacity(0.7), .pink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(tip.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
