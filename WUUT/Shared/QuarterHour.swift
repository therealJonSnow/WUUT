import Foundation

/// Wall-clock quarter-hour arithmetic.
///
/// Every slot boundary in WUUT comes from here. Boundaries are anchored to :00, :15,
/// :30 and :45 in the *local wall clock*, not to an offset from some epoch, which is
/// what makes hour-of-day comparisons across different days meaningful.
///
/// Arithmetic goes through `Calendar` rather than adding `TimeInterval`s so that a
/// daylight-saving transition produces the honest wall-clock answer. One slot per year
/// is therefore not 15 minutes long, which is why nothing in this app is allowed to
/// assume that it is — see `Slot.durationMinutes`.
public enum QuarterHour {

    public static let minutes: Int = 15

    /// Upper bound on iterations in the boundary walk. A logical day is capped by the
    /// auto-end cutoff at well under 24 hours (96 slots), so this only exists to make a
    /// calendar returning nonsense fail fast instead of spinning.
    private static let iterationLimit = 512

    /// The quarter-hour boundary at or before `date`. Seconds are discarded.
    public static func floor(_ date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = components.minute else { return date }
        components.minute = minute - (minute % minutes)
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? date
    }

    /// The first quarter-hour boundary *strictly after* `date`.
    ///
    /// Strictness matters: a slot that begins exactly on a boundary must end on the
    /// following one, not on itself.
    public static func next(after date: Date, calendar: Calendar) -> Date {
        var candidate = floor(date, calendar: calendar)
        var iterations = 0
        while candidate <= date && iterations < iterationLimit {
            candidate = advance(candidate, calendar: calendar)
            iterations += 1
        }
        return candidate
    }

    /// One quarter hour later, by the calendar.
    public static func advance(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: date)
            ?? date.addingTimeInterval(TimeInterval(minutes * 60))
    }

    public static func isBoundary(_ date: Date, calendar: Calendar) -> Bool {
        floor(date, calendar: calendar) == date
    }

    /// The next occurrence of `hour`:00 strictly after `date`, in `calendar`'s timezone.
    public static func nextOccurrence(ofHour hour: Int, after date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        guard let sameDay = calendar.date(from: components) else { return nil }
        if sameDay > date { return sameDay }
        return calendar.date(byAdding: .day, value: 1, to: sameDay)
    }
}
