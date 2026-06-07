import SwiftUI
import UIKit
import MapboxNavigationUIKit

struct RouteMapView: View {
    @ObservedObject var vm: TourDetailsViewModel
    @State private var selectedStopIndex: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map — full screen
            MapRepresentable(
                stops: vm.stops,
                routeCoords: vm.routeCoords,
                selectedStopIndex: selectedStopIndex
            )
            .edgesIgnoringSafeArea(.all)

            // Draggable stops list — nav button lives inside it
            if !vm.stops.isEmpty {
                StopsBottomSheet(
                    stops: vm.stops,
                    selectedIndex: $selectedStopIndex,
                    navButtonAction: vm.navigationRoutes != nil ? startNavigation : nil
                )
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .onAppear {
            if !vm.stops.isEmpty && vm.routeCoords.isEmpty {
                Task { await vm.buildWalkingRoute() }
            }
        }
        .onChange(of: vm.stops) { _, _ in
            Task { await vm.buildWalkingRoute() }
        }
    }

    private func startNavigation() {
        guard let routes = vm.navigationRoutes else { return }
        // Reuse shared NavigationOptions from NavigationContainer
        // to avoid "MapboxNavigationProvider instantiated twice" crash
        let vc = NavigationViewController(
            navigationRoutes: routes,
            navigationOptions: NavigationContainer.shared.navigationOptions
        )
        vc.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        UIApplication.shared.topMostViewController()?.present(vc, animated: true)
    }
}

// MARK: - Top-most VC helper
private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
