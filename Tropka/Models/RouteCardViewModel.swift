import SwiftUI
import Combine

@MainActor
final class RouteCardViewModel: ObservableObject {
    @Published var isSaved = false
    let route: TourRoute
    private let svc = SavedRoutesService()
    private var cancellable: AnyCancellable?

    @Published var isWished = false
    private let wishSvc = WishlistService()
    private var wishCancellable: AnyCancellable?

    init(route: TourRoute) {
        self.route = route
        cancellable = SavedRoutesStore.shared.$savedIDs
            .map { $0.contains(route.id) }
            .assign(to: \.isSaved, on: self)
        wishCancellable = WishlistStore.shared.$wishIDs
            .map { $0.contains(route.id) }
            .assign(to: \.isWished, on: self)
    }

    func save() async {
        guard !isSaved else { return }
        isSaved = true                              // optimistic UI
        try? await svc.save(routeID: route.id)      // сохраняем в Firebase
    }

    func toggleWish() {
        Task {
            let newValue = !isWished
            isWished = newValue                     // optimistic UI
            try? await wishSvc.set(newValue, routeID: route.id)
        }
    }
}

//
//
//@MainActor
//final class RouteCardViewModel: ObservableObject {
//    @Published var isSaved = false
//    let route: TourRoute
//    private let svc = SavedRoutesService()
//    private var cancellable: AnyCancellable?
//    
//    @Published var isWished = false
//    private let wishSvc = WishlistService()
//    private var wishCancellable: AnyCancellable?
//
//    init(route: TourRoute) {
//        self.route = route
//        cancellable = WishlistStore.shared.$savedIDs
//            .map { $0.contains(route.id) }
//            .assign(to: \.isSaved, on: self)
//        wishCancellable = WishlistStore.shared.$ids
//                    .map { $0.contains(route.id) }
//                    .assign(to: \.isWished, on: self)
//    }
//
//    func save() async {
//        guard !isSaved else { return }
//        isSaved = true                              // optimistic
//        try? await svc.save(routeID: route.id)      // ignore error for now
//    }
//    
//    func toggleWish() {
//        Task {
//            let new = !isWished
//            isWished = new                      // optimistic
//            try? await wishSvc.set(new, routeID: route.id)
//        }
//    }
//}
