import SwiftUI
import SDWebImageSwiftUI
import MapboxMaps   // на будущее — мини-карта для стопа

// MARK: – Route details ▸ экран одного маршрута
struct TourDetailsView: View {
    let route: TourRoute
    @StateObject private var vm = TourDetailsViewModel()
    @State private var showMap = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                //–– Thumbnail ──────────────────────────────────────────────
                if let url = route.thumbnailURL {
                    WebImage(url: url)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 6, y: 3)
                }

                //–– Title + author
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(.title2).bold()
                    Text("by \(route.authorUID)")          // ← потом подтянем имя автора
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                Divider()

                //–– Stops list / loader / empty
                Group {
                    if vm.isLoading {
                        ProgressView("Loading stops…")
                            .frame(maxWidth: .infinity)
                    } else if vm.stops.isEmpty {
                        Text("No stops added yet")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(vm.stops) { stop in
                                StopRow(stop: stop)
                            }
                        }
                    }
                }
                //–– MAP BUTTON (открывает картy) ––––––––––––––––––––
                if !vm.stops.isEmpty {
                    Button {
                        showMap = true
                    } label: {
                        Label("Show on Map", systemImage: "map")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }

                //–– Buy / Save button
                Button(
                    route.isFree
                    ? "Save Route"
                    : String(format: "Buy for €%.2f", route.price ?? 0)
                ) {
                    // TODO: save / buy logic
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.blue)
                .foregroundColor(.white)
                .font(.headline)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
        }
        .onAppear {
            vm.loadStops(routeID: route.id)
        }
        .navigationDestination(isPresented: $showMap) {
            RouteMapView(vm: vm)          // ← передаём тот же ViewModel
        }
//        .sheet(isPresented: $showMap) {
//            RouteMapView(vm: vm)
//        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: – Строка отдельного stop
private struct StopRow: View {
    let stop: Stop

    var body: some View {
        HStack(spacing: 14) {

            //–– фото точки (если есть)
            WebImage(url: stop.photoURL)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            //–– текст
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stop.orderIndex). \(stop.name)")
                    .font(.body).bold()

                // время + примечание
                Text("≈ \(stop.timeSpent) min"
                     + (stop.notes?.isEmpty == false ? " · \(stop.notes!)" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}
