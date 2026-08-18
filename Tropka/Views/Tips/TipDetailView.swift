import SDWebImageSwiftUI
import SwiftUI

/// A tip read as a short story: a few swipeable pages, each ending in the places
/// it talks about — and a way to turn the whole thing into a route in one tap.
struct TipDetailView: View {
    let tip: Tip

    @Environment(\.dismiss) private var dismiss
    @StateObject private var draftStore = RouteDraftStore.shared

    @State private var page = 0
    @State private var showEditor = false
    @State private var askAboutDraft = false

    /// Every place the tip mentions, in reading order, without repeats.
    private var allPlaces: [PlacePick] {
        var seen = Set<Int>()
        return tip.pages.flatMap(\.places).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $page) {
                    ForEach(Array(tip.pages.enumerated()), id: \.offset) { index, content in
                        TipPageView(page: content, tip: tip)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .bottom) {
                if !allPlaces.isEmpty { buildRouteBar }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tip.title).font(.subheadline.bold())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.subheadline.bold())
                    }
                }
            }
            .navigationDestination(isPresented: $showEditor) {
                RouteEditorView(
                    mode: .create,
                    prefillTitle: tip.title,
                    prefillDescription: "Built from the Tropka tip “\(tip.title)”."
                )
            }
            // The draft may already hold places collected on the map, and draining
            // it would silently mix them into this route.
            .confirmationDialog("You already have \(draftStore.count) place\(draftStore.count == 1 ? "" : "s") in a draft",
                                isPresented: $askAboutDraft,
                                titleVisibility: .visible) {
                Button("Add these to my draft") { startRoute(keepingDraft: true) }
                Button("Start fresh with this tip") { startRoute(keepingDraft: false) }
                Button("Cancel", role: .cancel) { }
            }
        }
        // Page views tell us where readers drop off inside a tip.
        .onChange(of: page) { _, newValue in
            Analytics.track(.tipPageViewed, [
                "tip_id": tip.id,
                "tip_title": tip.title,
                "page_index": newValue + 1,
                "page_count": tip.pages.count
            ])
        }
    }

    // MARK: - Pieces

    /// Segmented bar rather than dots: it reads as "there is more, swipe".
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(tip.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Color.primary : Color(.systemGray4))
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.2), value: page)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// The whole point of linking a tip to the catalogue: reading it can end in
    /// a route instead of in nothing.
    private var buildRouteBar: some View {
        Button {
            if draftStore.isEmpty {
                startRoute(keepingDraft: true)
            } else {
                askAboutDraft = true
            }
        } label: {
            Label("Build a route from this tip", systemImage: "map")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func startRoute(keepingDraft: Bool) {
        if !keepingDraft { draftStore.clear() }
        for place in allPlaces {
            draftStore.add(placeID: place.id, name: place.name, photoURL: place.photoURL)
        }
        Analytics.track(.tipRouteStarted, [
            "tip_id": tip.id,
            "tip_title": tip.title,
            "place_count": allPlaces.count,
            "kept_draft": keepingDraft
        ])
        showEditor = true
    }
}

// MARK: - Single page

private struct TipPageView: View {
    let page: TipPage
    let tip: Tip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cover

                Text(page.header)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                if !page.places.isEmpty { placesSection }

                if let footer = page.footer, !footer.isEmpty {
                    Text(footer)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var cover: some View {
        Group {
            if let url = URL(string: page.imageURL), !page.imageURL.isEmpty {
                WebImage(url: url) { $0.resizable().scaledToFill() }
                    placeholder: { Color(.systemGray5) }
            } else {
                Color(.systemGray5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// The payoff: everything the page names is one tap from the catalogue.
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.places.count == 1 ? "The place" : "The places")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            ForEach(page.places) { place in
                NavigationLink {
                    PlaceDetailView(placeID: place.id)
                } label: {
                    TipPlaceRow(place: place)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.track(.tipPlaceOpened, [
                        "tip_id": tip.id,
                        "tip_title": tip.title,
                        "place_id": place.id,
                        "place_name": place.name
                    ])
                })
            }
        }
    }
}

// MARK: - Linked place row

private struct TipPlaceRow: View {
    let place: PlacePick

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = place.photoURL {
                    WebImage(url: url,
                             context: [.imageThumbnailPixelSize: CGSize(width: 200, height: 200)]) {
                        $0.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: place.category.icon).foregroundColor(.secondary))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Label(place.category.displayName, systemImage: place.category.icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}
