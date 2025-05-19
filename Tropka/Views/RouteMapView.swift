import SwiftUI
import MapboxMaps

struct RouteMapView: View {
    @ObservedObject var vm: TourDetailsViewModel

    // Map-related
    @State private var mapView: MapView?           // нужен, чтобы управлять камерой
    @State private var pinManager: PointAnnotationManager?
    @State private var lineManager: PolylineAnnotationManager?

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1️⃣ Карта
            MapRepresentable(mapView: $mapView,
                             pinManager: $pinManager,
                             lineManager: $lineManager,
                             stops: vm.stops)            
                .edgesIgnoringSafeArea(.all)

            // 2️⃣ Мини‐лист остановок
            StopsBottomSheet(stops: vm.stops)
        }
        .onAppear {
            guard let first = vm.stops.first else { return }
            mapView?.camera.ease(
                to: CameraOptions(center: first.coordinates.clCoord,
                                  zoom: 13),
                duration: 0.8
            )
        }
    }
}
