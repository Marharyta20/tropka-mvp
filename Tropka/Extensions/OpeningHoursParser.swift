import Foundation

/// Parses the `opening_hours` JSON blob stored on `places`
/// (e.g. {"monday": "9 AM–5 PM", "saturday": "Closed", "sunday": "Open 24 hours"}).
enum OpeningHoursParser {

    private static let dayKeys = ["sunday", "monday", "tuesday", "wednesday",
                                 "thursday", "friday", "saturday"]

    // MARK: - Decoding

    static func schedule(jsonString: String?) -> [String: String]? {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let hours = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return hours
    }

    /// Week starting on Monday, which is how the rest of Europe reads a schedule.
    /// `isToday` lets the caller highlight the current row.
    static func week(jsonString: String?,
                     referenceDate: Date = Date(),
                     calendar: Calendar = .current) -> [(day: String, hours: String, isToday: Bool)] {
        guard let hours = schedule(jsonString: jsonString) else { return [] }
        let todayKey = dayKeys[calendar.component(.weekday, from: referenceDate) - 1]
        let mondayFirst = Array(dayKeys[1...]) + [dayKeys[0]]

        return mondayFirst.compactMap { key in
            guard let value = hours[key] else { return nil }
            return (day: key.capitalized, hours: value, isToday: key == todayKey)
        }
    }

    static func todayHours(jsonString: String?,
                           referenceDate: Date = Date(),
                           calendar: Calendar = .current) -> String? {
        guard let hours = schedule(jsonString: jsonString) else { return nil }
        let key = dayKeys[calendar.component(.weekday, from: referenceDate) - 1]
        return hours[key]
    }

    // MARK: - Open now

    /// Returns `true`/`false` if we can determine today's open status, or `nil` if the
    /// data is missing/malformed — callers should hide the open/closed badge in that case
    /// rather than guess.
    static func isOpenNow(
        jsonString: String?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool? {
        guard let todayHours = todayHours(jsonString: jsonString,
                                          referenceDate: referenceDate,
                                          calendar: calendar)
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

    // MARK: - Range parsing

    /// Parses "9 AM–5 PM" / "6:30 AM–6:30 PM" / "4–11 PM" into
    /// (startMinutes, endMinutes) since midnight.
    private static func parseRange(_ text: String) -> (Int, Int)? {
        let dashes = CharacterSet(charactersIn: "–—-")
        let parts = text.components(separatedBy: dashes)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }

        // Google writes the compact form "4–11 PM", where the meridiem appears only
        // once, at the end, and applies to both sides. Without this the start time
        // fails to parse and the place reads as closed all day — which was the case
        // for a large share of the catalogue.
        var startText = parts[0]
        if meridiem(in: startText) == nil, let endMeridiem = meridiem(in: parts[1]) {
            startText = "\(startText) \(endMeridiem)"
        }

        guard let start = parseTime(startText),
              let end = parseTime(parts[1])
        else { return nil }
        return (start, end)
    }

    private static func meridiem(in text: String) -> String? {
        let upper = text.uppercased()
        if upper.contains("AM") { return "AM" }
        if upper.contains("PM") { return "PM" }
        return nil
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
