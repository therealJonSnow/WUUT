import Foundation

/// Figures derived from a day's slots that the app did not previously show.
///
/// Pure and free of SwiftData fetches so it can be tested without a simulator. Everything
/// here is duration-weighted: the first and last slot of a day are short stubs, so counting
/// slots would overstate every number.
public enum DayStatistics {

    /// How an entry came to exist, collapsed into the three kinds worth reporting.
    ///
    /// This is the honesty signal about your own data. A week that is mostly reconstructed
    /// is a week you largely invented, and you should be able to see that.
    public enum Provenance: String, CaseIterable {
        /// Answered at the time — from a notification, in the app, or by voice.
        case live
        /// Pre-filled by a block-out. A prediction that you let stand.
        case planned
        /// Filled in afterwards, from memory.
        case reconstructed

        public var label: String {
            switch self {
            case .live: return "Written live"
            case .planned: return "Blocked out"
            case .reconstructed: return "Reconstructed"
            }
        }
    }

    public static func provenance(of slot: Slot) -> Provenance {
        switch slot.source {
        case .notification, .app, .siri: return .live
        case .blockOut: return .planned
        case .backfill: return .reconstructed
        }
    }

    /// Minutes by provenance, across any collection of slots.
    public static func minutesByProvenance(in slots: [Slot]) -> [Provenance: Int] {
        var totals: [Provenance: Int] = [:]
        for slot in slots where slot.state == .logged {
            totals[provenance(of: slot), default: 0] += slot.durationMinutes
        }
        return totals
    }

    /// The longest unbroken run of unaccounted time.
    ///
    /// More useful than the total: one 90-minute hole and six scattered quarter hours both
    /// report as "1h 30m", and they are completely different days.
    public static func longestGapMinutes(in slots: [Slot]) -> Int {
        let ordered = slots.sorted { $0.startAt < $1.startAt }
        var longest = 0
        var run = 0
        for slot in ordered {
            if slot.state == .unaccounted {
                run += slot.durationMinutes
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        return longest
    }

    /// How long after a slot closed you answered it, per entry, in minutes.
    ///
    /// Answering *during* the slot counts as zero rather than a negative number — you were
    /// not late, you were early.
    public static func responseDelaysMinutes(in slots: [Slot]) -> [Int] {
        slots.compactMap { slot in
            guard slot.state == .logged, let loggedAt = slot.loggedAt else { return nil }
            // A blocked-out slot was written before the fact and says nothing about how
            // quickly you respond to a prompt.
            guard provenance(of: slot) != .planned else { return nil }
            let delay = loggedAt.timeIntervalSince(slot.endAt) / 60
            return max(0, Int(delay.rounded()))
        }
    }

    /// Median delay, or nil when there is nothing to measure.
    ///
    /// Median rather than mean: one slot you answered eleven hours late would drag an
    /// average into meaninglessness.
    public static func medianResponseMinutes(in slots: [Slot]) -> Int? {
        let delays = responseDelaysMinutes(in: slots).sorted()
        guard !delays.isEmpty else { return nil }
        let middle = delays.count / 2
        if delays.count % 2 == 1 { return delays[middle] }
        return (delays[middle - 1] + delays[middle]) / 2
    }

    /// Logged share of everything that has settled one way or the other.
    public static func accountedFraction(logged: Int, unaccounted: Int) -> Double {
        let settled = logged + unaccounted
        guard settled > 0 else { return 1 }
        return Double(logged) / Double(settled)
    }

    /// A change in accounted percentage, in whole points, for a "up from X%" line.
    ///
    /// Returns nil when there is nothing to compare against, so callers can stay silent
    /// rather than inventing a baseline out of an empty week.
    public static func percentagePointChange(from previous: Double?, to current: Double) -> Int? {
        guard let previous else { return nil }
        return Int((current * 100).rounded()) - Int((previous * 100).rounded())
    }
}
