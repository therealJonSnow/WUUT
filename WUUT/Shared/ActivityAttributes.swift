import Foundation

import ActivityKit

/// The Live Activity payload.
///
/// Compiled into both the app and the widget extension — ActivityKit encodes this in one
/// process and decodes it in the other, so the two copies must be the same source file.
/// Keep it free of SwiftData and of anything else the extension cannot import.
public struct WUUTActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// The slot currently running. The lock screen counts down to `slotEnd` on its
        /// own via `Text(timerInterval:)`, so this stays truthful without the app running.
        public var slotStart: Date
        public var slotEnd: Date

        /// Finished slots still inside the backfill window. This is the number the whole
        /// lock-screen presence exists to show you.
        public var unloggedCount: Int

        /// Last thing you logged, already truncated for display.
        public var lastEntry: String?

        /// Set while a block-out is suppressing prompts.
        public var blockedUntil: Date?
        public var blockedLabel: String?

        /// How the day is going, 0–100. The countdown says when the next prompt lands;
        /// this says whether you are winning, which is the number that applies pressure.
        public var accountedPercent: Int

        public var unaccountedMinutes: Int

        /// The slot the lock-screen button acts on. A string because `ActivityAttributes`
        /// payloads are `Codable` and this crosses a process boundary.
        public var actionableSlotID: String?

        public init(
            slotStart: Date,
            slotEnd: Date,
            unloggedCount: Int,
            lastEntry: String? = nil,
            blockedUntil: Date? = nil,
            blockedLabel: String? = nil,
            accountedPercent: Int = 100,
            unaccountedMinutes: Int = 0,
            actionableSlotID: String? = nil
        ) {
            self.slotStart = slotStart
            self.slotEnd = slotEnd
            self.unloggedCount = unloggedCount
            self.lastEntry = lastEntry
            self.blockedUntil = blockedUntil
            self.blockedLabel = blockedLabel
            self.accountedPercent = accountedPercent
            self.unaccountedMinutes = unaccountedMinutes
            self.actionableSlotID = actionableSlotID
        }
    }

    /// When the logical day began. Fixed for the lifetime of the activity.
    public var dayStart: Date

    public init(dayStart: Date) {
        self.dayStart = dayStart
    }
}
