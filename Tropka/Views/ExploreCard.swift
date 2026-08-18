import SDWebImageSwiftUI
import SwiftUI

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
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation { isPresented.wrappedValue = false }
                        }
                    }
                    .transition(.opacity)
            }
        }
    }
}

/// One route in the Explore list.
///
/// The whole card is already a link to the route, so saving is a small overlay on
/// the cover rather than a full-width button competing with it for attention.
struct ExploreCard: View {
    @StateObject private var vm: RouteCardViewModel
    @State private var showToast = false
    @State private var toastText = ""
    let route: TourRoute

    init(route: TourRoute) {
        _vm = StateObject(wrappedValue: RouteCardViewModel(route: route))
        self.route = route
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover
            Text(route.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            metaRow
            if !route.tags.isEmpty { tagRow }
        }
        // The card is a link, so the whole block — including the empty space to the
        // right of the shorter rows — has to be tappable, not just the glyphs.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .toast(isPresented: $showToast) {
            Text(toastText)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Cover

    private var cover: some View {
        Group {
            if let url = route.thumbnailURL {
                WebImage(url: url) { $0.resizable().scaledToFill() }
                    placeholder: { Color(.systemGray5) }
            } else {
                // Same treatment as the featured card: a missing photo should read
                // as a style choice, not as a broken image.
                LinearGradient(colors: [.blue.opacity(0.7), .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: "map")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.9))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) { saveButton }
    }

    private var saveButton: some View {
        Button {
            Task {
                let saved = await vm.toggle()
                Analytics.track(saved ? .routeSaved : .routeUnsaved, [
                    "route_id": route.id,
                    "route_title": route.title,
                    "source": Analytics.Source.explore.rawValue
                ])
                toastText = saved ? "Saved to your routes" : "Removed from your routes"
                showToast = true
            }
        } label: {
            Image(systemName: vm.isSaved ? "bookmark.fill" : "bookmark")
                .font(.subheadline.bold())
                .foregroundColor(vm.isSaved ? .blue : .primary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .animation(.snappy(duration: 0.2), value: vm.isSaved)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vm.isSaved ? "Remove from saved" : "Save route")
        .contentShape(Circle())
        .padding(10)
    }

    // MARK: - Text

    private var metaRow: some View {
        HStack(spacing: 6) {
            if let author = route.authorName {
                AvatarView(stored: route.authorAvatar, size: 20)
                Text(author)
                    .lineLimit(1)
                Text("·")
            }
            // A brand new route has no reviews yet; "0.0" reads as a bad score.
            if route.rating > 0 {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", route.rating))
                Text("·")
            }
            Text("\(route.stopsCount) stops")
            Text("·")
            Text(route.duration.formattedDuration)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }

    private var tagRow: some View {
        HStack(spacing: 6) {
            ForEach(route.tags.prefix(3), id: \.self) { tag in
                Text(tag.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6), in: Capsule())
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
