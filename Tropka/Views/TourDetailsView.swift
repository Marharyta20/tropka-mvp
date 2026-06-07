import SwiftUI
import SDWebImageSwiftUI
import MapboxMaps
import CoreLocation

// MARK: – Route details ▸ экран одного маршрута
struct TourDetailsView: View {
    let route: TourRoute
    let locationManager = CLLocationManager()
    @StateObject private var vm = TourDetailsViewModel()

    @State private var showMap         = false
    @State private var showReviewSheet = false

    // MARK: Save / Buy
    @ViewBuilder
        private var saveBuyButton: some View {
            if vm.isSaved {
            }
            else {
                if route.isActuallyFree {
                    Button {
                        Task {
                            await vm.saveRoute(routeID: route.id)
                        }
                    } label: {
                        Text(vm.isSaved ? "Saved" : "Get for free")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isSaved)
                }
                else {
                    Button {
                        // TODO: payment flow
                    } label: {
                        Text(String(format: "Buy €%.2f", route.price ?? 0))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

    // MARK: Review button
    @ViewBuilder
    private var reviewButton: some View {
        if vm.isSaved {
            Button { showReviewSheet = true } label: {
                Label(
                    vm.myReview == nil ? "Write a review" : "Edit your review",
                    systemImage: vm.myReview == nil ? "square.and.pencil" : "pencil"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // –– Thumbnail
                if let url = route.thumbnailURL {
                    WebImage(url: url)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 6, y: 3)
                }

                // –– Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(.title2).bold()
                }

                Divider()

                // –– Stops / loader / empty
                Group {
                    if vm.isLoading {
                        ProgressView("Loading stops…")
                            .frame(maxWidth: .infinity)
                    } else if vm.stops.isEmpty {
                        Text("No stops added yet")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(vm.stops) { StopRow(stop: $0) }
                        }
                    }
                }

                // –– Кнопка «Show on Map»
                if !vm.stops.isEmpty {
                    Button {
                        showMap = true
                    } label: {
                        Label("Show on Map", systemImage: "map")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // –– Save / Buy
                saveBuyButton

                // –– Review
                reviewButton
            }
            .padding(20)
        }
        .onAppear {
                    // 1. Запрос геолокации (Новое)
                    locationManager.requestWhenInUseAuthorization()
                    
                    // 2. Загрузка данных (Старое - ВЕРНУЛИ НА МЕСТО)
                    Task {
                        await vm.load(routeID: route.id)
                    }
                }
        // –– Лист для Review
        .sheet(isPresented: $showReviewSheet) {
            ReviewFormSheet(
                draft: vm.myReview
                  ?? UserReview(
                         id: "",
                         routeID: route.id,
                         userID: supabase.auth.currentUser?.id.uuidString ?? "",
                         routeTitle: route.title,
                         rating: 5,
                         text: "",
                         createdAt: .now
                     )
            ) { newReview in
                Task {
                    await vm.saveReview(newReview)
                }
            }
        }
        .navigationDestination(isPresented: $showMap) {
            RouteMapView(vm: vm)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: – Строка отдельного stop
private struct StopRow: View {
    let stop: Stop
    var body: some View {
        HStack(spacing: 14) {
            WebImage(url: stop.photoURL)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stop.orderIndex). \(stop.name)")
                    .font(.body).bold()
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

// MARK: – Review form sheet
struct ReviewFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: UserReview
    let onSave: (UserReview) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    Picker("Rating", selection: $draft.rating) {
                        ForEach(1...5, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Review") {
                    TextEditor(text: $draft.text)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Your review")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
