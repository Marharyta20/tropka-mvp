import SwiftUI
import MapboxMaps

struct RouteMapView: View {
    @ObservedObject var vm: TourDetailsViewModel   // передаём уже загруженный VM

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
                             stops: vm.stops)            // кастомный UIViewRepresentable
                .edgesIgnoringSafeArea(.all)

            // 2️⃣ Мини‐лист остановок
            StopsBottomSheet(stops: vm.stops)
        }
        .onAppear {
            guard let first = vm.stops.first else { return }
            mapView?.camera.ease(
                to: CameraOptions( center: first.coordinate,
                                   zoom: 13),
                duration: 0.8)
        }
    }
}
