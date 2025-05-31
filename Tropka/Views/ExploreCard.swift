import SwiftUI
import SDWebImageSwiftUI

extension View {
    func toast<Content: View>(isPresented: Binding<Bool>,
                              duration: TimeInterval = 1.5,
                              @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                content()
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now()+duration) {
                            withAnimation { isPresented.wrappedValue = false }
                        }
                    }
                    .transition(.opacity)
            }
        }
    }
}


struct ExploreCard: View {
    @StateObject private var vm: RouteCardViewModel
    @State private var showToast = false
    let route: TourRoute
    
    init(route: TourRoute) {
        _vm = StateObject(wrappedValue: RouteCardViewModel(route: route))
        self.route = route
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            //–– Cover (❌ без автора)
            WebImage(url: route.thumbnailURL)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            //–– Title + price/free badge ─────────────────────────────
            HStack(alignment: .top, spacing: 8) {
                Text(route.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer(minLength: 4)
                
                Text(route.isActuallyFree
                     ? "FREE"
                     : String(format: "€%.2f", route.price ?? 0))
                .font(.caption2).bold()
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .foregroundColor(.white)
                .background(route.isActuallyFree ? Color.green
                            : Color.black.opacity(0.85))
                .clipShape(Capsule())
            }
            
            //–– Meta (rating • duration)
            HStack(spacing: 8) {
                Label(
                    String(format: "%.1f", route.rating),
                    systemImage: "star.fill"
                )
                Label(
                    String(format: "%.1f h", route.duration),
                    systemImage: "clock"
                )
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            //–– Tags
            HStack {
                ForEach(route.tags.prefix(3), id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(.caption2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            
            //–– CTA + wishlist
            HStack(spacing: 12) {
                Button(
                    vm.route.isActuallyFree
                    ? (vm.isSaved ? "Saved" : "Get for free")
                    : String(format: "Buy €%.2f", vm.route.price ?? 0)
                ) {
                    if vm.route.isActuallyFree {
                        Task {
                            await vm.save()
                            showToast = true
                        }
                    } else {
                        // TODO: payment flow
                    }
                }
                .disabled(vm.route.isActuallyFree && vm.isSaved)
                .frame(maxWidth: .infinity)
                .font(.subheadline.bold())
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button {
                    vm.toggleWish()
                } label: {
                    Image(systemName: vm.isWished ? "heart.fill" : "heart")
                        .font(.title3)
                        .padding(12)
                }
                .foregroundColor(vm.isWished ? .red : .gray)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
        .toast(isPresented: $showToast) {
            Text("Route added")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}
