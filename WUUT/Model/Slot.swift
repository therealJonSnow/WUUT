import Foundation
import SwiftData

/// A single interval of the day.
///
/// Stored as an explicit start and end rather than an index into a 15-minute grid, because
/// the first and last slot of every day are shorter stubs. See SPEC §3.
@Model
public final class Slot {

    public var id: UUID = UUID()

    public var startAt: Date = Date.distantPast
    public var endAt: Date = Date.distantPast

    public var text: String?
    public var category: LogCategory?

    /// Normalised tag keys. Stored inline rather than as a SwiftData many-to-many: at 64
    /// slots a day the join buys nothing, and inline keys make export trivial. The `Tag`
    /// model exists alongside this purely to rank autocomplete suggestions.
    public var tagKeys: [String] = []

    /// Backing store for `state`. Raw strings keep `#Predicate` straightforward.
    public var stateRaw: String = SlotState.pending.rawValue

    /// Backing store for `source`.
    public var sourceRaw: String = EntrySource.app.rawValue

    public var loggedAt: Date?

    public var day: Day?

    public init(
        id: UUID = UUID(),
        startAt: Date,
        endAt: Date,
        state: SlotState = .pending,
        source: EntrySource = .app
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.stateRaw = state.rawValue
        self.sourceRaw = source.rawValue
        self.tagKeys = []
    }

    public var state: SlotState {
        get { SlotState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    public var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    /// Real length, rounded to the nearest minute. Never assume 15.
    public var durationMinutes: Int {
        let seconds = endAt.timeIntervalSince(startAt)
        guard seconds > 0 else { return 0 }
        return Int((seconds / 60).rounded())
    }

    /// A stub is the short first or last slot of a day.
    public var isStub: Bool {
        durationMinutes < QuarterHour.minutes
    }

    public func contains(_ date: Date) -> Bool {
        date >= startAt && date < endAt
    }

    public func isInProgress(at now: Date) -> Bool {
        contains(now)
    }

    /// Whether this slot can still be filled in.
    ///
    /// The in-progress slot always can. A finished one can until its backfill window
    /// expires, at which point `BackfillReconciler` locks it.
    public func isFillable(at now: Date, backfillWindowMinutes: Int) -> Bool {
        guard state != .unaccounted else { return false }
        if isInProgress(at: now) { return true }
        if now < startAt { return false }
        return now < endAt.addingTimeInterval(TimeInterval(backfillWindowMinutes * 60))
    }

    /// When this slot stops being fillable.
    public func lockDate(backfillWindowMinutes: Int) -> Date {
        endAt.addingTimeInterval(TimeInterval(backfillWindowMinutes * 60))
    }

    public var displayWindow: String {
        Formatters.window(from: startAt, to: endAt)
    }
}
