import SwiftUI

struct ExploreView: View {
    @StateObject private var vm = ExploreViewModel()

    var body: some View {
        NavigationView {
            Group {
                if vm.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = vm.errorMsg {
                    ErrorBlock(message: msg) { vm.loadRoutes() }
                } else {
                    /// Обычный список «один-за-другим»
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(vm.routes) { r in
                                NavigationLink {
                                                                TourDetailsView(route: r)   // ⬅️ передаём весь объект
                                                            } label: {
                                                                ExploreCard(route: r)
                                                            }
                                                            .buttonStyle(.plain)          // убираем эффект нажатия
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 32)   // нижний отступ
                    }
                    .refreshable { vm.loadRoutes() }   // pull-to-refresh
                }
            }
            .navigationTitle("Explore")
        }
        .onAppear { if vm.routes.isEmpty { vm.loadRoutes() } }
    }
}

private struct ErrorBlock: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
