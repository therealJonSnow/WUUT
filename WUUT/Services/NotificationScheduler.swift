import Foundation
import UserNotifications

/// Schedules the quarter-hour prompts.
///
/// The whole design turns on one platform limit: **iOS keeps at most 64 pending local
/// notification requests**. A 16-hour day is 64 slots, and at three prompts each that is 192
/// requests — iOS would silently keep only the 64 soonest and the app would go quiet around
/// lunchtime with no error anywhere.
///
/// So prompts are scheduled in a rolling window of the next `promptWindowSlotCount` slots
/// (18 by default, which is 4.5 hours of coverage) and topped up on every app wake: launch,
/// foreground, a notification reply, logging, day start and end, block-out changes, and a
/// background refresh task as a backstop. See SPEC §5.
public final class NotificationScheduler {

    // MARK: Identifiers

    public static let promptCategoryIdentifier = "SLOT_PROMPT"
    public static let replyActionIdentifier = "SLOT_REPLY"
    public static let sameAsLastActionIdentifier = "SLOT_SAME_AS_LAST"

    private static let slotPrefix = "slot"
    private static let summaryIdentifier = "day-summary"
    private static let blockEndIdentifier = "block-end"
    private static let startReminderIdentifier = "start-reminder"

    /// One thread for the whole app, so five unlogged slots make one stack on the lock
    /// screen rather than five. The per-slot escalation still collapses inside it.
    private static let threadIdentifier = "wuut.ledger"

    /// The platform limit, for the record. Never scheduled up to.
    public static let platformPendingLimit = 64

    public static let userInfoSlotIDKey = "slotID"

    private let center: UNUserNotificationCenter
    private let settings: AppSettings

    public init(center: UNUserNotificationCenter = .current(), settings: AppSettings = .shared) {
        self.center = center
        self.settings = settings
    }

    // MARK: - Identifier encoding
    //
    // Dot-separated because a UUID string already contains hyphens.

    public static func identifier(slotID: UUID, index: Int) -> String {
        "\(slotPrefix).\(slotID.uuidString).\(index)"
    }

    public static func slotID(fromIdentifier identifier: String) -> UUID? {
        let parts = identifier.split(separator: ".")
        guard parts.count == 3, parts[0] == slotPrefix else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    // MARK: - Setup

    /// Registers the prompt category with its two actions.
    ///
    /// `Reply` is the feature the habit depends on — it logs an entry from the banner without
    /// opening the app. `Same as last` turns an hour-long task into four taps and no typing.
    public func registerCategories() {
        let reply = UNTextInputNotificationAction(
            identifier: Self.replyActionIdentifier,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Log",
            textInputPlaceholder: "What were you up to?"
        )
        let sameAsLast = UNNotificationAction(
            identifier: Self.sameAsLastActionIdentifier,
            title: "Same as last",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.promptCategoryIdentifier,
            actions: [reply, sameAsLast],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - The rolling window

    /// Replaces every scheduled prompt with the ones the current state implies.
    ///
    /// Rebuilding wholesale rather than diffing: at 54 requests it costs nothing, and it means
    /// the scheduled set cannot drift out of step with the store.
    /// - Parameters:
    ///   - lastEntry: the most recent logged entry's text, shown in the body so the
    ///     "Same as last" action is something you can act on without opening the app.
    ///   - backlogCount: how many finished slots are already unlogged. The backlog is what
    ///     predicts abandonment, so it belongs on the prompt rather than only in the app.
    public func refreshPrompts(
        for slots: [Slot],
        now: Date,
        calendar: Calendar,
        lastEntry: String? = nil,
        backlogCount: Int = 0
    ) async {
        await cancelAllPrompts()

        let windowSize = max(1, settings.promptWindowSlotCount)
        let offsets = settings.promptOffsets
        let backfillWindow = settings.backfillWindowMinutes

        let window = slots
            .filter { $0.state == .pending }
            .sorted { $0.startAt < $1.startAt }
            .prefix(windowSize)

        for slot in window {
            for (index, offset) in offsets.enumerated() {
                let fireDate = slot.endAt.addingTimeInterval(offset)
                // A prompt whose moment has already passed is not worth re-firing; the slot
                // is in the catch-up queue instead.
                guard fireDate > now else { continue }

                let content = promptContent(
                    for: slot,
                    index: index,
                    backfillWindowMinutes: backfillWindow,
                    calendar: calendar,
                    lastEntry: lastEntry,
                    backlogCount: backlogCount
                )
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: Self.identifier(slotID: slot.id, index: index),
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    private func promptContent(
        for slot: Slot,
        index: Int,
        backfillWindowMinutes: Int,
        calendar: Calendar,
        lastEntry: String?,
        backlogCount: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let window = Formatters.window(from: slot.startAt, to: slot.endAt, calendar: calendar)

        // Showing the previous entry is what makes the "Same as last" action usable: without
        // it you are being asked to repeat something you cannot see.
        let previous = lastEntry.map { "last: \($0)" }

        switch index {
        case 0:
            content.title = "What were you up to?"
            content.body = [window, previous].compactMap { $0 }.joined(separator: " · ")
        case 1:
            content.title = backlogCount > 1 ? "\(backlogCount) slots behind" : "Still unlogged"
            content.body = [window, previous ?? "a minute now saves a guess later"]
                .joined(separator: " · ")
        default:
            let lockTime = Formatters.time(
                slot.lockDate(backfillWindowMinutes: backfillWindowMinutes),
                calendar: calendar
            )
            content.title = "Last call"
            content.body = "\(window) is struck out at \(lockTime)"
        }

        content.categoryIdentifier = Self.promptCategoryIdentifier
        content.threadIdentifier = Self.threadIdentifier
        content.sound = .default
        content.userInfo = [Self.userInfoSlotIDKey: slot.id.uuidString]
        if settings.useTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        return content
    }

    /// Drops the outstanding follow-ups for one slot. Called the instant it gets logged, so
    /// you are never nagged about something you have already answered.
    public func cancelPrompts(forSlotID slotID: UUID) {
        let identifiers = (0..<4).map { Self.identifier(slotID: slotID, index: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    public func cancelAllPrompts() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("\(Self.slotPrefix).") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func cancelEverything() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Other notifications

    /// The day's only nudge: real numbers, once, with nothing to configure. See SPEC §7.5.
    public func deliverDaySummary(title: String, body: String) async {
        guard settings.daySummaryEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = Self.threadIdentifier
        let request = UNNotificationRequest(
            identifier: Self.summaryIdentifier,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// Fires when a block-out ends, so you resume logging rather than drifting.
    public func scheduleBlockEnd(at date: Date, label: String, calendar: Calendar) async {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Block finished"
        content.body = "\(label) — back to logging"
        content.sound = .default
        content.threadIdentifier = Self.threadIdentifier
        if settings.useTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: Self.blockEndIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    public func cancelBlockEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.blockEndIdentifier])
    }

    // MARK: - Start of day

    /// Keeps the daily "start the day?" reminder in step with whether one is running.
    ///
    /// A single repeating request rather than one per day: the 64-request ceiling is already
    /// mostly spent on the prompt window, and a repeating calendar trigger costs one slot.
    /// While a day is active the request is removed, and it goes back when the day ends.
    public func refreshStartReminder(dayIsActive: Bool, calendar: Calendar) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.startReminderIdentifier])
        guard settings.startReminderEnabled, !dayIsActive else { return }

        let content = UNMutableNotificationContent()
        content.title = "Start the day?"
        content.body = "Nothing is being recorded yet."
        content.sound = .default
        content.threadIdentifier = Self.threadIdentifier
        if settings.useTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }

        var components = DateComponents()
        components.hour = settings.startReminderHour
        components.minute = settings.startReminderMinute
        components.calendar = calendar

        let request = UNNotificationRequest(
            identifier: Self.startReminderIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    /// Diagnostics for the Settings screen — proof the window is where it should be.
    public func pendingPromptCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix("\(Self.slotPrefix).") }.count
    }
}
