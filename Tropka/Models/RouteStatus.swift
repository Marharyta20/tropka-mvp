import SwiftUI

/// Visibility of a route. Mirrors the `public.route_status` enum in Postgres,
/// and is enforced there by row level security — not just in the UI.
enum RouteStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case `private`
    case `public`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft:   return "Draft"
        case .private: return "Private"
        case .public:  return "Public"
        }
    }

    /// Shown under the picker so the choice doesn't need guessing.
    var explanation: String {
        switch self {
        case .draft:   return "Only you. Still a work in progress."
        case .private: return "Only you. Finished, just not shared."
        case .public:  return "Anyone can find it in Explore."
        }
    }

    var icon: String {
        switch self {
        case .draft:   return "pencil.and.outline"
        case .private: return "lock.fill"
        case .public:  return "globe"
        }
    }

    var tint: Color {
        switch self {
        case .draft:   return .orange
        case .private: return .secondary
        case .public:  return .green
        }
    }

    var isVisibleToOthers: Bool { self == .public }
}

// MARK: - Badge

/// Small status pill used in lists and on the route header.
struct RouteStatusBadge: View {
    let status: RouteStatus

    var body: some View {
        Label(status.title, systemImage: status.icon)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.15))
            .foregroundColor(status.tint)
            .clipShape(Capsule())
    }
}
