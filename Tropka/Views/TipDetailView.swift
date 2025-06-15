import SwiftUI

struct TipDetailView: View {
    let tip: Tip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                ForEach(tip.pages) { page in
                    ScrollView {
                        VStack(spacing: 16) {
                            AsyncImage(url: URL(string: page.imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.secondary)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text(page.header)
                                .font(.title2)
                                .bold()
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)

                            Text(page.body)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal)

                            if let footer = page.footer {
                                Text(footer)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                        }
                        .padding()
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .padding()
            }
        }
    }
}
