import SwiftUI
import MapboxMaps   // если потом будем рисовать мини-карту

struct TourDetailsView: View {
    let route: Route            // ваш Route без FirestoreSwift
    @StateObject private var vm = TourDetailsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // — thumbnail
                if let url = route.thumbnailURL {
                    AsyncImage(url: url) { img in
                        img.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    .clipped()
                }

                // — основная инфо
                Text(route.title).font(.title2).bold()
                Text("by \(route.authorUID)").foregroundColor(.secondary)

                // — список остановок (когда загрузятся)
                if vm.isLoading {
                    ProgressView().padding()
                } else if vm.stops.isEmpty {
                    Text("No stops yet").foregroundColor(.secondary)
                } else {
                    ForEach(vm.stops) { stop in
                        HStack {
                            Text("\(stop.order). \(stop.name)")
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // — кнопка Save/Buy
                Button(
                    route.isFree
                        ? "Save Route"
                        : String(format: "Buy for €%.2f", route.price ?? 0)
                ) {
                    // TODO: save / buy logic
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .onAppear { vm.loadStops(for: route.id) }
    }
}
