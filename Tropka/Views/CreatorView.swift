import SwiftUI

struct CreatorView: View {
    @StateObject private var vm = TipsViewModel()
    @State private var selectedTip: Tip?
    @State private var searchText = ""
    
    var filteredTips: [Tip] {
        if searchText.isEmpty {
            return vm.tips
        } else {
            return vm.tips.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // ——— Page Header —————————————————
                Text("Useful Travel Tips")
                    .font(.largeTitle).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // ——— Search Bar —————————————————
                // (iOS 15+)
                // hides the default nav bar title in favor of our own
                Spacer().frame(height: 0)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search tips")
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(filteredTips) { tip in
                        Button {
                            selectedTip = tip
                        } label: {
                            VStack(spacing: 8) {
                                // Banner image
                                AsyncImage(url: URL(string: tip.bannerURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 140)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 140)
                                            .clipped()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 140)
                                            .foregroundColor(.secondary)
                                    @unknown default: EmptyView()
                                    }
                                }
                                .cornerRadius(12)
                                
                                // Title from Firestore
                                Text(tip.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical)
            }
            .task { await vm.loadTips() }
            .fullScreenCover(item: $selectedTip) { tip in
                TipDetailView(tip: tip)
            }
        }
    }
}
