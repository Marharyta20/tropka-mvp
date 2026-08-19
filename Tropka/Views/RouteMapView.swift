import MapboxNavigationUIKit
import SwiftUI
import UIKit

/// The route on a map.
///
/// Stops are a swipeable carousel rather than a hand-dragged sheet: one swipe moves
/// to the next stop and the camera follows, which is how you actually read a walking
/// route. The list is still one tap away for anyone who wants the whole thing.
struct RouteMapView: View {
    @ObservedObject var vm: TourDetailsViewModel

    @State private var selectedStopIndex = 0
    @State private var recenterTrigger = 0
    @State private var showList = false

    var body: some View {
        MapRepresentable(
            stops: vm.stops,
            routeCoords: vm.routeCoords,
            selectedStopIndex: selectedStopIndex,
            recenterTrigger: recenterTrigger
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) { mapControls }
        .safeAreaInset(edge: .bottom) {
            if !vm.stops.isEmpty { bottomBar }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showList) {
            StopListSheet(stops: vm.stops, selectedIndex: $selectedStopIndex)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !vm.stops.isEmpty && vm.routeCoords.isEmpty {
                Task { await vm.buildWalkingRoute() }
            }
        }
        .onChange(of: vm.stops) { _, _ in
            Task { await vm.buildWalkingRoute() }
        }
        .onChange(of: selectedStopIndex) { _, index in
            guard vm.stops.indices.contains(index) else { return }
            Analytics.track(.routeStopStepped, [
                "place_id": vm.stops[index].placeID,
                "place_name": vm.stops[index].name,
                "order_index": vm.stops[index].orderIndex
            ])
        }
    }

    // MARK: - Controls

    private var mapControls: some View {
        VStack(spacing: 10) {
            circleButton("arrow.up.left.and.arrow.down.right") {
                recenterTrigger += 1
            }
            circleButton("list.bullet") {
                showList = true
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        VStack(spacing: 10) {
            TabView(selection: $selectedStopIndex) {
                ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                    StopCard(stop: stop, index: index, total: vm.stops.count)
                        .padding(.horizontal, 16)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 108)

            if vm.navigationRoutes != nil {
                Button(action: startNavigation) {
                    Label("Start navigation", systemImage: "location.north.line.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func startNavigation() {
        guard let routes = vm.navigationRoutes else { return }
        Analytics.track(.navigationStarted, ["stops_count": vm.stops.count])
        // Reuse the shared NavigationOptions from NavigationContainer to avoid the
        // "MapboxNavigationProvider instantiated twice" crash.
        let controller = NavigationViewController(
            navigationRoutes: routes,
            navigationOptions: NavigationContainer.shared.navigationOptions
        )
        controller.modalPresentationStyle = .fullScreen
        UIApplication.shared.topMostViewController()?.present(controller, animated: true)
    }
}

// MARK: - Stop card

private struct StopCard: View {
    let stop: Stop
    let index: Int
    let total: Int

    var body: some View {
        NavigationLink {
            PlaceDetailView(placeID: stop.placeID)
        } label: {
            HStack(spacing: 12) {
                PlaceThumbnail(url: stop.photoURL,
                               category: stop.category,
                               thumbnailPixelSize: CGSize(width: 200, height: 200))
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop \(index + 1) of \(total)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)

                    Text(stop.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("≈ \(stop.timeSpent) min")
                        if let notes = stop.notes, !notes.isEmpty {
                            Text("· \(notes)").lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full list

private struct StopListSheet: View {
    let stops: [Stop]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    Button {
                        selectedIndex = index
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(index == selectedIndex ? Color.accentColor : Color(.systemGray4))
                                    .frame(width: 26, height: 26)
                                Text("\(stop.orderIndex)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text("≈ \(stop.timeSpent) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
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
