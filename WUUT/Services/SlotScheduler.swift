import Foundation

/// A slot that *should* exist, before anything is persisted.
public struct SlotPlan: Equatable, Hashable {
    public let startAt: Date
    public let endAt: Date

    public init(startAt: Date, endAt: Date) {
        self.startAt = startAt
        self.endAt = endAt
    }

    public var durationMinutes: Int {
        Int((endAt.timeIntervalSince(startAt) / 60).rounded())
    }
}

/// Works out which slots a day should contain. Pure — no store, no clock of its own.
///
/// The rule, from SPEC §3.1:
///
/// - The first slot is a **stub** from the moment you tapped Start to the next quarter hour.
///   Start at 07:07 and it runs 07:07 → 07:15.
/// - Everything after that is aligned 15 minutes.
/// - The last slot is a stub truncated to the moment you tapped End.
/// - A stub shorter than `minimumStubMinutes` is not created at all, so starting at 07:14
///   gives a single first slot of 07:14 → 07:30 rather than a one-minute sliver.
public struct SlotScheduler {

    public var calendar: Calendar
    public var minimumStubMinutes: Int

    /// Guard on the boundary walk. The auto-end cutoff caps a day well below this.
    private let iterationLimit = 512

    public init(calendar: Calendar, minimumStubMinutes: Int) {
        self.calendar = calendar
        self.minimumStubMinutes = max(0, minimumStubMinutes)
    }

    /// Every slot that should exist for a day started at `dayStart`, up to and including the
    /// slot containing `now`.
    ///
    /// The in-progress slot is included — it has to exist for the Live Activity to show it
    /// and for you to be able to log it early.
    public func slots(dayStart: Date, through now: Date) -> [SlotPlan] {
        guard now >= dayStart else { return [] }

        var plans: [SlotPlan] = []
        var cursor = dayStart
        var isFirst = true
        var iterations = 0

        while cursor <= now && iterations < iterationLimit {
            iterations += 1
            var end = QuarterHour.next(after: cursor, calendar: calendar)

            // Suppress a too-short opening stub by absorbing it into the following slot.
            if isFirst, end.timeIntervalSince(cursor) < TimeInterval(minimumStubMinutes * 60) {
                end = QuarterHour.next(after: end, calendar: calendar)
            }

            plans.append(SlotPlan(startAt: cursor, endAt: end))
            cursor = end
            isFirst = false
        }

        return plans
    }

    /// How a day ending at `end` should close.
    ///
    /// Returns the truncated final slot, or `nil` when the trailing stub would be too short
    /// to be worth keeping — in which case the day simply ends at the previous boundary.
    public func truncation(dayStart: Date, endingAt end: Date) -> SlotPlan? {
        guard end > dayStart else { return nil }
        let plans = slots(dayStart: dayStart, through: end)
        guard let last = plans.last else { return nil }

        // `end` landed exactly on a boundary: the final slot is already whole.
        if end >= last.endAt { return last }

        let truncated = SlotPlan(startAt: last.startAt, endAt: end)
        if truncated.endAt.timeIntervalSince(truncated.startAt) < TimeInterval(minimumStubMinutes * 60) {
            return nil
        }
        return truncated
    }

    /// The upcoming slot boundaries after `now`, which is what notifications are scheduled
    /// against. Used to fill the rolling window in `NotificationScheduler`.
    public func upcomingBoundaries(dayStart: Date, after now: Date, limit: Int) -> [Date] {
        guard limit > 0 else { return [] }
        var boundaries: [Date] = []

        // Start from the end of the slot currently running.
        let existing = slots(dayStart: dayStart, through: now)
        var cursor = existing.last?.endAt ?? QuarterHour.next(after: dayStart, calendar: calendar)

        var iterations = 0
        while boundaries.count < limit && iterations < iterationLimit {
            iterations += 1
            if cursor > now { boundaries.append(cursor) }
            cursor = QuarterHour.next(after: cursor, calendar: calendar)
        }
        return boundaries
    }

    /// When a day started at `startedAt` should be closed automatically if you forget.
    ///
    /// The next occurrence of `hour`:00 after the start — but pushed a further day if that
    /// would give an absurdly short day, so someone starting at 00:30 isn't cut off at 02:00.
    public func autoEndDate(startedAt: Date, hour: Int, minimumDayHours: Int = 4) -> Date? {
        guard let candidate = QuarterHour.nextOccurrence(ofHour: hour, after: startedAt, calendar: calendar) else {
            return nil
        }
        if candidate.timeIntervalSince(startedAt) >= TimeInterval(minimumDayHours * 3600) {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }
}
