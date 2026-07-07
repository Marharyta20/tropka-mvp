import Foundation

/// Parses the `opening_hours` JSON blob stored on `places`
/// (e.g. {"monday": "9 AM–5 PM", "saturday": "Closed", "sunday": "Open 24 hours"})
/// and figures out whether a place is open right now.
enum OpeningHoursParser {

    /// Returns `true`/`false` if we can determine today's open status, or `nil` if the
    /// data is missing/malformed — callers should hide the open/closed badge in that case
    /// rather than guess.
    static func isOpenNow(
        jsonString: String?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool? {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let hours = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }

        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let weekday = calendar.component(.weekday, from: referenceDate) // 1 = Sunday ... 7 = Saturday
        guard dayNames.indices.contains(weekday - 1),
              let todayHours = hours[dayNames[weekday - 1]]
        else { return nil }

        let trimmed = todayHours.trimmingCharacters(in: .whitespaces)
        if trimmed.caseInsensitiveCompare("Closed") == .orderedSame { return false }
        if trimmed.range(of: "24 hours", options: .caseInsensitive) != nil { return true }

        let nowMinutes = calendar.component(.hour, from: referenceDate) * 60
            + calendar.component(.minute, from: referenceDate)

        // A day can have multiple comma-separated ranges (e.g. a lunch-break split)
        for chunk in trimmed.components(separatedBy: ",") {
            guard let (start, end) = parseRange(chunk) else { continue }
            if start <= end {
                if nowMinutes >= start && nowMinutes < end { return true }
            } else {
                // Range wraps past midnight, e.g. "3 PM–1 AM"
                if nowMinutes >= start || nowMinutes < end { return true }
            }
        }
        return false
    }

    /// Parses "9 AM–5 PM" / "6:30 AM–6:30 PM" into (startMinutes, endMinutes) since midnight.
    private static func parseRange(_ text: String) -> (Int, Int)? {
        let dashes = CharacterSet(charactersIn: "–—-")
        let parts = text.components(separatedBy: dashes).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let start = parseTime(parts[0]),
              let end = parseTime(parts[1])
        else { return nil }
        return (start, end)
    }

    /// Parses "9 AM" / "6:30 PM" into minutes since midnight.
    private static func parseTime(_ text: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["h:mm a", "h a"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                let comps = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
                return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        }
        return nil
    }
}
