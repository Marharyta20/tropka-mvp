import SwiftUI
import UIKit
import MapboxNavigationUIKit

struct RouteMapView: View {
    @ObservedObject var vm: TourDetailsViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            MapRepresentable(
                stops: vm.stops,
                routeCoords: vm.routeCoords
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                if vm.navigationRoutes != nil {
                    Button {
                        startNavigation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Start Navigation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                        .padding(.horizontal, 40)
                        .shadow(radius: 5)
                    }
                    .padding(.bottom, 20)
                }
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
        guard let routes = vm.navigationRoutes else {
            print("NavigationRoutes not ready")
            return
        }

        let navigationViewController = NavigationViewController(
            navigationRoutes: routes,
            navigationOptions: NavigationOptions()
        )

        navigationViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        UIApplication.shared.topMostViewController()?.present(navigationViewController, animated: true)
    }

}

// MARK: - Top-most VC helper
private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var topController = keyWindow?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
