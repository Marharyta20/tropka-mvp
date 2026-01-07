import SwiftUI
import MapboxMaps

struct RouteMapView: View {
    
    // ViewModel приходит извне
    @ObservedObject var vm: TourDetailsViewModel
    
    // ❌ УДАЛЕНО: Больше не нужны @State для mapView и менеджеров,
    // так как MapRepresentable теперь справляется сам.

    var body: some View {
        ZStack(alignment: .bottom) {
            
            // ❶ Карта + аннотации
            // ✅ ИСПРАВЛЕНО: Передаем только данные
            MapRepresentable(
                stops: vm.stops,
                routeCoords: vm.routeCoords
            )
            .edgesIgnoringSafeArea(.all)
            
            // ❷ Мини-лист остановок (оставляем как было)

            StopsBottomSheet(stops: vm.stops)
            
            // Если компонента нет, можно временно показать кнопку для теста:
            /*
            VStack {
                Spacer()
                Text("Stops: \(vm.stops.count)")
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .padding()
            }
            */
        }
        .onAppear {
            // Если stops есть, а линии еще нет – пробуем построить
            if !vm.stops.isEmpty && vm.routeCoords.isEmpty {
                vm.buildWalkingRoute()
            }
        }
        // ✅ ИСПРАВЛЕНО: Синтаксис onChange для iOS 17+
        .onChange(of: vm.stops) { _, _ in
            vm.buildWalkingRoute()
        }
    }
}
