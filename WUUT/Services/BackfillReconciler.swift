import Foundation

/// Decides which slots have run out of backfill time.
///
/// Pure, and driven entirely by stored timestamps rather than by timers. That is the point:
/// the app must reach the same conclusion whether it was open all day or shut for a week —
/// including across the 7-day provisioning blackout. See SPEC §7.3.
public struct BackfillReconciler {

    public var backfillWindowMinutes: Int

    public init(backfillWindowMinutes: Int) {
        self.backfillWindowMinutes = max(0, backfillWindowMinutes)
    }

    /// Slots that should flip from `pending` to `unaccounted`.
    ///
    /// A slot expires once `endAt + window` has passed. The in-progress slot is never
    /// included, and neither is anything in the future.
    public func expiredSlots(in slots: [Slot], now: Date) -> [Slot] {
        slots.filter { slot in
            guard slot.state == .pending else { return false }
            guard slot.endAt <= now else { return false }
            return now >= slot.lockDate(backfillWindowMinutes: backfillWindowMinutes)
        }
    }

    /// Finished slots still open to backfill, oldest first — the catch-up queue.
    public func fillableSlots(in slots: [Slot], now: Date) -> [Slot] {
        slots
            .filter { slot in
                guard slot.state == .pending else { return false }
                guard slot.endAt <= now else { return false }
                return now < slot.lockDate(backfillWindowMinutes: backfillWindowMinutes)
            }
            .sorted { $0.startAt < $1.startAt }
    }

    /// Slots still awaiting a prompt — the fillable queue plus the one in progress. This is
    /// what the notification window schedules against.
    public func promptableSlots(in slots: [Slot], now: Date) -> [Slot] {
        slots
            .filter { slot in
                guard slot.state == .pending else { return false }
                if slot.isInProgress(at: now) { return true }
                if slot.startAt > now { return true }
                return now < slot.lockDate(backfillWindowMinutes: backfillWindowMinutes)
            }
            .sorted { $0.startAt < $1.startAt }
    }
}
