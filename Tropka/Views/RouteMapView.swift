import SwiftUI
import MapboxMaps

struct RouteMapView: View {

    // ViewModel приходит извне (TourDetailsView его создаёт)
    @ObservedObject var vm: TourDetailsViewModel

    // ― Mapbox managers, нужны как @State - обёртки для UIViewRepresentable
    @State private var mapView:    MapboxMaps.MapView?
    @State private var pinManager: MapboxMaps.PointAnnotationManager?
    @State private var lineManager: MapboxMaps.PolylineAnnotationManager?

    var body: some View {
        ZStack(alignment: .bottom) {

            // ❶ Карта + аннотации
            MapRepresentable(
                mapView:     $mapView,
                pinManager:  $pinManager,
                lineManager: $lineManager,
                stops:       vm.stops,
                routeCoords: vm.routeCoords        // ← линия «по дорогам»
            )
            .edgesIgnoringSafeArea(.all)

            // ❷ Мини-лист остановок
            StopsBottomSheet(stops: vm.stops)         // тот, что уже был
        }
        .onAppear {
            // Если stops уже загружены – строим линию
            if !vm.stops.isEmpty && vm.routeCoords.isEmpty {
                vm.buildWalkingRoute()
            }
        }
        // Перестраиваем линию, когда stops обновились
        .onChange(of: vm.stops) { vm.buildWalkingRoute() }
    }
}
