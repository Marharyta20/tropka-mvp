import SwiftUI
import CoreLocation
import MapboxMaps

struct TourDetailsView: View {
    let route: Route
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: — IMAGE SLIDER
                    TabView {
                        // In the future replace with real array of image URLs
                        AsyncImage(url: route.thumbnailURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            case .failure:
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .clipped()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 200)
                        .clipped()
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 200)

                    // MARK: — TITLE, AUTHOR, RATING & PRICE
                    Text(route.title)
                        .font(.title2).bold()
                    Text("by \(route.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Label(String(format: "%.1f", route.rating),
                              systemImage: "star.fill")
                            .font(.caption)
                        Text(route.isFree
                             ? "Free"
                             : String(format: "€%.2f", route.price ?? 0))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    // MARK: — TAGS
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(route.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // MARK: — MAP
                    // Display map with stops as pins
                    if !route.stops.isEmpty {
                        MapScreenView(
                            stops: route.stops.map { geoPoint in
                                CLLocationCoordinate2D(
                                    latitude: geoPoint.latitude,
                                    longitude: geoPoint.longitude
                                )
                            }
                        )
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    }

                    // MARK: — ACTION BUTTON
                    Button {
                        // TODO: purchase or save logic
                        isPresented = false
                    } label: {
                        Text(route.isFree
                             ? "Save Route"
                             : "Buy for \(String(format: "€%.2f", route.price ?? 0))")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 24)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
