import SwiftUI

struct TipDetailView: View {
    let tip: Tip
    @Environment(\.dismiss) private var dismiss

    /// Tracks which page is showing
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // ——— Dot Pager Indicator —————————————
                HStack(spacing: 8) {
                    ForEach(tip.pages.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex
                                  ? Color.primary
                                  : Color.secondary.opacity(0.5))
                            .frame(width: idx == currentIndex ? 8 : 6,
                                   height: idx == currentIndex ? 8 : 6)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                // ——— Paged Content ————————————————
                TabView(selection: $currentIndex) {
                    ForEach(Array(tip.pages.enumerated()), id: \.offset) { idx, page in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Image
                                AsyncImage(url: URL(string: page.imageURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.secondary)
                                    @unknown default: EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                // Header
                                Text(page.header)
                                    .font(.title2).bold()
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                // Body
                                Text(page.body)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal)

                                // Footer (optional)
                                if let footer = page.footer {
                                    Text(footer)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentIndex)
            }
            .background(Color(.systemBackground))
            .edgesIgnoringSafeArea(.bottom)

            // ——— Close Button ———————————————
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .padding()
            }
        }
    }
}
