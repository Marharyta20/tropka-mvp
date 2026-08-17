import SwiftUI
import SDWebImageSwiftUI

/// Bottom sheet with details for the selected place.
struct PlaceBottomSheet: View {
    @Binding var place: Place?
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var isDragging = false
    @State private var relatedRoutes: [TourRoute] = []
    @State private var isLoadingRoutes = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if let place = place {
                    collapsedContent(for: place)
                        .padding(.horizontal, 20)

                    if height > minHeight + 50 {
                        expandedContent(for: place)
                            .transition(.opacity)
                    }
                }

                Spacer()
            }
            .frame(width: geometry.size.width, height: height)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(radius: 10)
            .offset(y: geometry.size.height - height)
            .gesture(dragGesture)
            .task(id: place?.id) {
                guard let placeID = place?.id else {
                    relatedRoutes = []
                    return
                }
                await loadRelatedRoutes(placeID: placeID)
            }
        }
    }

    private func collapsedContent(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(place.name)
                    .font(.headline)

                Spacer()

                Label(place.category.displayName,
                      systemImage: place.category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", place.rating))
                        .font(.subheadline)
                    Text("(\(place.reviewCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let isOpen = place.isOpenNow {
                    Text("•")
                        .foregroundColor(.secondary)

                    Text(isOpen ? "Open Now" : "Closed")
                        .font(.subheadline)
                        .foregroundColor(isOpen ? .green : .red)
                }

                if let distance = place.distanceFromUser {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(formatDistance(distance))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    // Single real photo for the place, decoded at a capped pixel size so we're not
    // pulling a full-resolution Google-photo-sized image into memory for a small card.
    @ViewBuilder
    private func placePhoto(for place: Place) -> some View {
        Group {
            if let url = place.photoURL {
                WebImage(
                    url: url,
                    context: [.imageThumbnailPixelSize: CGSize(width: 600, height: 400)]
                ) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func expandedContent(for place: Place) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                placePhoto(for: place)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(place.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Tours")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    if isLoadingRoutes {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    } else if relatedRoutes.isEmpty {
                        Text("No tours include this place yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    } else {
                        ForEach(relatedRoutes) { route in
                            CompactRouteCard(route: route)
                                .padding(.horizontal, 20)
                                // These cards don't navigate anywhere yet — tracking the tap
                                // shows how much demand there is for wiring them up.
                                .onTapGesture {
                                    Analytics.track(.placeRouteTapped, [
                                        "place_id": place.id,
                                        "route_id": route.id,
                                        "route_title": route.title
                                    ])
                                }
                        }
                    }
                }

                Button(action: {
                    // Same here: no review flow for places yet, but we can measure the demand.
                    Analytics.track(.reviewFormOpened, [
                        "place_id": place.id,
                        "target": "place",
                        "is_edit": false
                    ])
                }) {
                    Text("Leave a Review")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                let newHeight = height - value.translation.height
                height = min(max(newHeight, minHeight), maxHeight)
            }
            .onEnded { _ in
                isDragging = false
                let staysCollapsed = height < minHeight + 50
                withAnimation(.spring()) {
                    if height < minHeight + 50 {
                        height = minHeight
                    } else if height > maxHeight - 100 {
                        height = maxHeight
                    } else {
                        height = maxHeight / 2
                    }
                }
                // Pulling the sheet open is the real "I'm interested in this place" signal.
                if !staysCollapsed, let place {
                    Analytics.track(.mapPlaceExpanded, [
                        "place_id": place.id,
                        "place_name": place.name,
                        "category": place.category.displayName,
                        "related_routes_count": relatedRoutes.count
                    ])
                }
            }
    }

    // MARK: - Data loading

    private func loadRelatedRoutes(placeID: String) async {
        guard let placeIDInt = Int(placeID) else { return }
        isLoadingRoutes = true
        defer { isLoadingRoutes = false }

        do {
            struct RouteStopRow: Decodable {
                let routes: TourRoute
            }
            let rows: [RouteStopRow] = try await supabase
                .from("route_stops")
                .select("routes(*)")
                .eq("place_id", value: placeIDInt)
                .execute()
                .value
            relatedRoutes = rows.map(\.routes)
        } catch {
            print("PlaceBottomSheet: failed to load related routes:", error)
            relatedRoutes = []
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        meters < 1000 ? String(format: "%.0f m", meters)
                       : String(format: "%.1f km", meters / 1000)
    }
}

/// Compact preview of a tour route.
struct CompactRouteCard: View {
    let route: TourRoute

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(route.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
