import Foundation
import Combine

// MARK: - DraftStop

/// A stop while it is being edited. Unlike `Stop` it has no database id yet and
/// its time/notes are mutable — those are exactly the two things the author fills in.
struct DraftStop: Identifiable, Equatable {
    let id: UUID
    let placeID: Int
    let name: String
    let photoURL: URL?
    var timeSpent: Int
    var notes: String

    init(id: UUID = UUID(),
         placeID: Int,
         name: String,
         photoURL: URL? = nil,
         timeSpent: Int = 30,
         notes: String = "") {
        self.id = id
        self.placeID = placeID
        self.name = name
        self.photoURL = photoURL
        self.timeSpent = timeSpent
        self.notes = notes
    }

    /// Rebuilds a draft stop from a saved one, for the edit flow.
    init(stop: Stop) {
        self.init(placeID: stop.placeID,
                  name: stop.name,
                  photoURL: stop.photoURL,
                  timeSpent: stop.timeSpent,
                  notes: stop.notes ?? "")
    }
}

// MARK: - RouteDraftStore

/// Holds stops collected outside the editor — today that means the "Add to route"
/// button on the map's place sheet. The editor drains this on open, so a user can
/// wander the map, tap a few places, then go build the route from them.
@MainActor
final class RouteDraftStore: ObservableObject {
    static let shared = RouteDraftStore()
    private init() {}

    @Published private(set) var stops: [DraftStop] = []

    var isEmpty: Bool { stops.isEmpty }
    var count: Int { stops.count }

    func contains(placeID: Int) -> Bool {
        stops.contains { $0.placeID == placeID }
    }

    /// Returns false when the place is already in the draft, so the caller can
    /// tell "added" apart from "already there" in its toast.
    @discardableResult
    func add(placeID: Int, name: String, photoURL: URL? = nil) -> Bool {
        guard !contains(placeID: placeID) else { return false }
        stops.append(DraftStop(placeID: placeID, name: name, photoURL: photoURL))
        return true
    }

    func remove(placeID: Int) {
        stops.removeAll { $0.placeID == placeID }
    }

    /// Hands the collected stops over and empties the store.
    func drain() -> [DraftStop] {
        defer { stops.removeAll() }
        return stops
    }

    func clear() {
        stops.removeAll()
    }
}
