import Foundation
import SwiftData

/// One logical day of logging.
///
/// A logical day is **not** a calendar day: it starts when you tap Start the Day and can run
/// past midnight. `date` is the logical day it belongs to; every slot timestamp is absolute.
@Model
public final class Day {

    public var id: UUID = UUID()

    /// Start of the calendar day the logging *began* on, local. The grouping key for week
    /// views — an evening that runs to 01:30 belongs to the day it started.
    public var date: Date = Date.distantPast

    /// The timezone the day was recorded in. Slot arithmetic is replayed in this zone so
    /// history stays readable after travel.
    public var timeZoneIdentifier: String = TimeZone.current.identifier

    public var startedAt: Date?
    public var endedAt: Date?

    /// True when the auto-end cutoff closed the day rather than you tapping End the Day.
    public var endedAutomatically: Bool = false

    public var summaryDeliveredAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Slot.day)
    public var slots: [Slot] = []

    public init(
        id: UUID = UUID(),
        date: Date,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        startedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startedAt = startedAt
        self.endedAutomatically = false
        self.slots = []
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    /// A calendar pinned to the timezone this day was recorded in.
    public var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    public var isActive: Bool {
        startedAt != nil && endedAt == nil
    }

    public var orderedSlots: [Slot] {
        slots.sorted { $0.startAt < $1.startAt }
    }

    // MARK: - Aggregates
    //
    // All duration-weighted. The first and last slot of a day are short stubs, so counting
    // slots and multiplying by 15 would overstate every single day. See SPEC §3.2.

    /// Total minutes the day covers, logged or not.
    public var elapsedMinutes: Int {
        orderedSlots.reduce(0) { $0 + $1.durationMinutes }
    }

    public var loggedMinutes: Int {
        orderedSlots.filter { $0.state == .logged }.reduce(0) { $0 + $1.durationMinutes }
    }

    public var unaccountedMinutes: Int {
        orderedSlots.filter { $0.state == .unaccounted }.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Minutes in slots still open to you — the in-progress slot and anything inside the
    /// backfill window.
    public var pendingMinutes: Int {
        orderedSlots.filter { $0.state == .pending }.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Logged share of everything that has already closed one way or the other.
    ///
    /// Excludes still-pending slots, so the figure doesn't start every morning at 0% and
    /// climb — it reflects how you have actually done on the slots that are settled.
    public var accountedFraction: Double {
        let settled = loggedMinutes + unaccountedMinutes
        guard settled > 0 else { return 1 }
        return Double(loggedMinutes) / Double(settled)
    }

    /// Minutes per category, duration-weighted. Unlogged slots are excluded; ask
    /// `unaccountedMinutes` for those.
    public func minutesByCategory() -> [UUID: Int] {
        var totals: [UUID: Int] = [:]
        for slot in slots where slot.state == .logged {
            guard let categoryID = slot.category?.id else { continue }
            totals[categoryID, default: 0] += slot.durationMinutes
        }
        return totals
    }

    /// The longest unbroken stretch of unaccounted time. See `DayStatistics`.
    public var longestGapMinutes: Int {
        DayStatistics.longestGapMinutes(in: slots)
    }

    /// Median minutes between a slot closing and you answering it.
    public var medianResponseMinutes: Int? {
        DayStatistics.medianResponseMinutes(in: slots)
    }

    /// Minutes split by how the entry came to exist — live, blocked out, reconstructed.
    public func minutesByProvenance() -> [DayStatistics.Provenance: Int] {
        DayStatistics.minutesByProvenance(in: slots)
    }

    /// Logged minutes with no category assigned — usually banner replies the suggester
    /// couldn't place. Surfaced in the UI so they can be cleared in a batch.
    public var uncategorisedMinutes: Int {
        slots.filter { $0.state == .logged && $0.category == nil }
            .reduce(0) { $0 + $1.durationMinutes }
    }
}
