import Foundation

extension Int {
    /// Formats a duration given in minutes as "Xh Ym" (or "Ym" if under an hour).
    /// Used anywhere a route/stop duration is shown, so all screens agree on formatting.
    var formattedDuration: String {
        guard self > 0 else { return "—" }
        if self < 60 { return "\(self) min" }
        let h = self / 60
        let m = self % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
