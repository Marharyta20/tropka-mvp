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
            
            //–– Cover
            Group {
                if let url = route.thumbnailURL {
                    WebImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            //–– Title ─────────────────────────────
            Text(route.title)
                .font(.headline)
                .lineLimit(2)

            //–– Author
            if let author = route.authorName {
                HStack(spacing: 6) {
                    AvatarView(stored: route.authorAvatar, size: 22)
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            //–– Meta (rating • duration)
            HStack(spacing: 8) {
                Label(
                    String(format: "%.1f", route.rating),
                    systemImage: "star.fill"
                )
                Label(
                    route.duration.formattedDuration,
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
            
            //–– CTA
            Button(vm.isSaved ? "Saved" : "Save") {
                Task {
                    await vm.save()
                    Analytics.track(.routeSaved, [
                        "route_id": route.id,
                        "route_title": route.title,
                        "source": Analytics.Source.explore.rawValue
                    ])
                    showToast = true
                }
            }
            .disabled(vm.isSaved)
            .frame(maxWidth: .infinity)
            .font(.subheadline.bold())
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .toast(isPresented: $showToast) {
            Text("Route added")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}
