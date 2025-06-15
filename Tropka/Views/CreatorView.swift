import SwiftUI

struct CreatorView: View {
    @StateObject private var vm = TipsViewModel()
    @State private var selectedTip: Tip?

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(vm.tips) { tip in
                        Button {
                            selectedTip = tip
                        } label: {
                            AsyncImage(url: URL(string: tip.bannerURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 240, height: 130)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 240, height: 130)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo")
                                        .frame(width: 240, height: 130)
                                        .background(Color.gray.opacity(0.2))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Tips")
            .task { await vm.loadTips() }
            .fullScreenCover(item: $selectedTip) { tip in
                TipDetailView(tip: tip)
            }
        }
    }
}
