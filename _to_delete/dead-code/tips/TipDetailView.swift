import SwiftUI

struct TipDetailView: View {
    let tip: Tip
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // dots
                HStack(spacing: 8) {
                    ForEach(tip.pages.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == page ? .primary : .secondary)
                            .frame(width: idx == page ? 8 : 6,
                                   height: idx == page ? 8 : 6)
                    }
                }
                .padding(.top, 16)

                // pages
                TabView(selection: $page) {
                    ForEach(Array(tip.pages.enumerated()), id: \.offset) { idx, p in
                        TipPageView(page: p).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // close
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .padding()
            }
        }
    }
}

// MARK: single page
private struct TipPageView: View {
    let page: TipPage
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                AsyncImage(url: URL(string: page.imageURL)) { phase in
                    switch phase {
                    case .empty:   ProgressView()
                    case .failure: Image(systemName: "photo").resizable()
                                   .scaledToFit().foregroundColor(.secondary)
                    case .success(let img):
                        img.resizable().scaledToFit()
                    @unknown default: EmptyView()
                    }
                }

                Text(page.header)
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .multilineTextAlignment(.leading)

                if let footer = page.footer, !footer.isEmpty {
                    Text(footer)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}
