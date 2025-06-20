import SwiftUI

struct CreatorView: View {

    @StateObject private var vm = TipsViewModel()
    @State private   var selectedTip: Tip?
    @State private   var searchText  = ""

    // filter
    private var visibleTips: [Tip] {
        guard !searchText.isEmpty else { return vm.tips }
        return vm.tips.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            listSection()
                .listStyle(.plain)
                .refreshable { await vm.reload() }
                .navigationTitle("Useful Travel Tips")
                .searchable(text: $searchText)
                .task { await vm.reload() }
                .sheet(item: $selectedTip) { TipDetailView(tip: $0) }
        }
    }

    @ViewBuilder
    private func listSection() -> some View {
        List {
            Section {
                ForEach(visibleTips) { tip in
                    TipBannerCell(tip: tip)
                        .onTapGesture { selectedTip = tip }
                        .onAppear {
                            if tip == vm.tips.last {
                                Task { await vm.fetchMore() }
                            }
                        }
                }

                if vm.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
        }
    }
}

// MARK: banner cell
private struct TipBannerCell: View {
    let tip: Tip
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: tip.bannerURL)) { phase in
                switch phase {
                case .empty:   ProgressView().frame(height: 140)
                case .failure: Image(systemName: "photo").resizable()
                               .scaledToFit()
                               .frame(height: 140)
                               .foregroundColor(.secondary)
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(height: 140).clipped()
                @unknown default: EmptyView()
                }
            }
            .cornerRadius(12)

            Text(tip.title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
    }
}
