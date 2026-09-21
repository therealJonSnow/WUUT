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

        public init(
            slotStart: Date,
            slotEnd: Date,
            unloggedCount: Int,
            lastEntry: String? = nil,
            blockedUntil: Date? = nil,
            blockedLabel: String? = nil
        ) {
            self.slotStart = slotStart
            self.slotEnd = slotEnd
            self.unloggedCount = unloggedCount
            self.lastEntry = lastEntry
            self.blockedUntil = blockedUntil
            self.blockedLabel = blockedLabel
        }
    }

    /// When the logical day began. Fixed for the lifetime of the activity.
    public var dayStart: Date

    public init(dayStart: Date) {
        self.dayStart = dayStart
    }
}
