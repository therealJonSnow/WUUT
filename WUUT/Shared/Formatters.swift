import Foundation

public enum Formatters {

    /// "07:15" — 24-hour, because a quarter-hour grid reads better without am/pm.
    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// "07:15 – 07:30"
    public static func window(from start: Date, to end: Date, calendar: Calendar = .current) -> String {
        "\(time(start, calendar: calendar)) – \(time(end, calendar: calendar))"
    }

    /// "1h 45m", "45m", "8m". Minutes are rounded, never truncated to slot counts.
    public static func duration(minutes: Int) -> String {
        if minutes <= 0 { return "0m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    public static func percent(_ fraction: Double) -> String {
        let clamped = max(0, min(1, fraction))
        return "\(Int((clamped * 100).rounded()))%"
    }

    /// "Monday 21 September"
    public static func longDate(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: date)
    }

    /// "Mon"
    public static func weekdayInitials(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}
