import ActivityKit
import Foundation
import Observation
import SwiftData

/// Owns the logging loop: starting and ending a day, materialising slots, recording entries,
/// expiring the backfill window, and keeping the lock screen and notification queue in step.
///
/// Everything funnels through `reconcile(now:)`, which derives the correct state from stored
/// timestamps rather than from timers. That is deliberate: the app has to reach the same
/// conclusion whether it was open all day or shut for a week — including across the 7-day
/// provisioning blackout a free Apple ID imposes. See SPEC §7.3.
@MainActor
@Observable
public final class DayController {

    private let context: ModelContext
    private let settings: AppSettings
    private let notifications: NotificationScheduler
    private let activities: LiveActivityController
    private let suggester = CategorySuggester()

    /// Tolerance when matching a planned slot to a stored one. Dates round-trip through a
    /// `Double` in the store, so exact equality is not something to rely on.
    private let matchTolerance: TimeInterval = 1

    public private(set) var activeDay: Day?

    /// Surfaced in the UI when a save fails. Silence would be worse than an ugly banner.
    public var lastErrorMessage: String?

    public init(
        context: ModelContext,
        settings: AppSettings = .shared,
        notifications: NotificationScheduler,
        activities: LiveActivityController
    ) {
        self.context = context
        self.settings = settings
        self.notifications = notifications
        self.activities = activities
    }

    // MARK: - Derived helpers

    private func calendar(for day: Day?) -> Calendar {
        day?.calendar ?? .current
    }

    private func scheduler(for day: Day?) -> SlotScheduler {
        SlotScheduler(
            calendar: calendar(for: day),
            minimumStubMinutes: settings.minimumStubMinutes
        )
    }

    private var reconciler: BackfillReconciler {
        BackfillReconciler(backfillWindowMinutes: settings.backfillWindowMinutes)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            lastErrorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: - Launch

    /// Call once per launch, before any view reads state.
    public func bootstrap() {
        seedCategoriesIfNeeded()
        notifications.registerCategories()
        activities.adoptExisting()
        loadActiveDay()
        reconcile()
        refreshStartReminder()
    }

    private func seedCategoriesIfNeeded() {
        let existing = (try? context.fetch(FetchDescriptor<LogCategory>())) ?? []
        guard existing.isEmpty else { return }
        for category in DefaultCategories.makeAll() {
            context.insert(category)
        }
        save()
    }

    /// Fetched and filtered in memory rather than through a `#Predicate`. At one row per day
    /// the cost is nothing, and it keeps optional-relationship predicates out of the picture.
    private func loadActiveDay() {
        let descriptor = FetchDescriptor<Day>(sortBy: [SortDescriptor(\Day.date, order: .reverse)])
        let days = (try? context.fetch(descriptor)) ?? []
        activeDay = days.first { $0.startedAt != nil && $0.endedAt == nil }
    }

    public func allDays() -> [Day] {
        let descriptor = FetchDescriptor<Day>(sortBy: [SortDescriptor(\Day.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    public func activeCategories() -> [LogCategory] {
        let descriptor = FetchDescriptor<LogCategory>(sortBy: [SortDescriptor(\LogCategory.sortOrder)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { !$0.isArchived }
    }

    // MARK: - Day lifecycle

    public func startDay(at now: Date = .now) {
        loadActiveDay()
        guard activeDay == nil else {
            reconcile(now: now)
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        let day = Day(
            date: calendar.startOfDay(for: now),
            timeZoneIdentifier: TimeZone.current.identifier,
            startedAt: now
        )
        context.insert(day)
        activeDay = day
        save()

        materialiseSlots(for: day, through: now)
        save()

        if let state = activityState(for: day, now: now) {
            activities.start(dayStart: now, state: state)
        }
        refreshPrompts(for: day, now: now)
        refreshStartReminder(now: now)
    }

    /// Closes the day.
    ///
    /// Note what this deliberately does *not* do: it does not force unlogged slots to lock.
    /// Ending the day stops the prompting, but a slot still inside its backfill window stays
    /// fillable and the catch-up queue still shows it. Ending the day early shouldn't shorten
    /// the window you were promised.
    public func endDay(at now: Date = .now, automatic: Bool = false) {
        loadActiveDay()
        guard let day = activeDay, let start = day.startedAt else { return }

        materialiseSlots(for: day, through: now)

        let plan = scheduler(for: day)
        let ordered = day.orderedSlots

        // Truncate the slot that was running when you tapped End, before anything is
        // deleted — reading properties off a deleted model is not something to risk.
        if let truncation = plan.truncation(dayStart: start, endingAt: now) {
            if let running = ordered.first(where: {
                abs($0.startAt.timeIntervalSince(truncation.startAt)) < matchTolerance
            }) {
                running.endAt = truncation.endAt
            }
        }

        // Then drop the slots that shouldn't survive the day ending: anything a block-out
        // created in the future, plus a trailing stub too short to be worth keeping (in
        // which case the day simply ends at the previous boundary).
        let keepsTrailingStub = plan.truncation(dayStart: start, endingAt: now) != nil
        let doomed = ordered.filter { slot in
            if slot.startAt >= now { return true }
            if !keepsTrailingStub && slot.contains(now) { return true }
            return false
        }
        for slot in doomed {
            context.delete(slot)
        }

        day.endedAt = now
        day.endedAutomatically = automatic
        save()

        notifications.cancelBlockEnd()
        Task { await notifications.cancelAllPrompts() }
        activities.end()

        let summary = daySummary(for: day)
        Task { await notifications.deliverDaySummary(title: summary.title, body: summary.body) }
        day.summaryDeliveredAt = .now
        save()

        activeDay = nil
        refreshStartReminder(now: now)
    }

    // MARK: - Reconciliation

    /// The single path by which time passing changes anything.
    public func reconcile(now: Date = .now) {
        if activeDay == nil { loadActiveDay() }
        guard let day = activeDay, let start = day.startedAt else { return }

        // A day you forgot to end gets closed at the cutoff, not left to accumulate slots
        // until you next open the app.
        if let autoEnd = scheduler(for: day).autoEndDate(startedAt: start, hour: settings.autoEndHour),
           now >= autoEnd {
            materialiseSlots(for: day, through: autoEnd)
            endDay(at: autoEnd, automatic: true)
            return
        }

        materialiseSlots(for: day, through: now)

        for slot in reconciler.expiredSlots(in: day.slots, now: now) {
            slot.state = .unaccounted
        }
        save()

        if let state = activityState(for: day, now: now) {
            activities.start(dayStart: start, state: state)
        }
        refreshPrompts(for: day, now: now)
    }

    /// Creates any slot the plan says should exist and the store does not have.
    ///
    /// Existing slots are never rewritten — the plan is deterministic, so a slot already in
    /// the store matches it, and the one exception (a truncated final slot) belongs to a day
    /// that has already ended.
    private func materialiseSlots(for day: Day, through now: Date) {
        guard let start = day.startedAt else { return }
        let plans = scheduler(for: day).slots(dayStart: start, through: now)
        guard !plans.isEmpty else { return }

        let existing = day.slots
        let blocks = activeBlockOuts()

        for plan in plans {
            let alreadyThere = existing.contains {
                abs($0.startAt.timeIntervalSince(plan.startAt)) < matchTolerance
            }
            guard !alreadyThere else { continue }

            let slot = Slot(startAt: plan.startAt, endAt: plan.endAt)
            context.insert(slot)
            slot.day = day

            // A slot created inside a live block-out arrives pre-filled.
            if let block = blocks.first(where: { $0.covers(slot: slot) }) {
                apply(block: block, to: slot)
            }
        }
    }

    private func refreshPrompts(for day: Day, now: Date) {
        let promptable = reconciler.promptableSlots(in: day.slots, now: now)
        let backlog = reconciler.fillableSlots(in: day.slots, now: now).count
        let last = lastLoggedText(in: day)
        let cal = calendar(for: day)
        Task {
            await notifications.refreshPrompts(
                for: promptable,
                now: now,
                calendar: cal,
                lastEntry: last,
                backlogCount: backlog
            )
        }
    }

    /// The most recent entry's text, truncated for a notification body.
    private func lastLoggedText(in day: Day) -> String? {
        day.orderedSlots
            .last { $0.state == .logged && $0.text?.isEmpty == false }?
            .text
            .map { $0.count > 48 ? String($0.prefix(47)) + "…" : $0 }
    }

    /// Keeps the "start the day?" reminder in step. Forgetting to start costs a whole day
    /// silently, which is a worse failure than missing any single quarter hour.
    private func refreshStartReminder(now: Date = .now) {
        let active = activeDay != nil
        let cal = calendar(for: activeDay)
        Task {
            await notifications.refreshStartReminder(dayIsActive: active, calendar: cal)
        }
    }

    // MARK: - Logging

    @discardableResult
    public func log(
        slot: Slot,
        text: String,
        category: LogCategory?,
        tagKeys: [String],
        source: EntrySource,
        now: Date = .now
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard slot.state != .unaccounted else { return false }

        slot.text = trimmed
        slot.category = category ?? suggestedCategory(for: trimmed)
        slot.tagKeys = normalisedTagKeys(tagKeys)
        slot.state = .logged
        slot.source = source
        slot.loggedAt = now

        recordTagUsage(slot.tagKeys, displayNames: tagKeys, now: now)
        save()

        notifications.cancelPrompts(forSlotID: slot.id)

        if let day = slot.day {
            if let state = activityState(for: day, now: now) {
                activities.update(state)
            }
            refreshPrompts(for: day, now: now)
        }
        return true
    }

    /// Copies the previous logged entry forward. The cheap way through a long meeting.
    @discardableResult
    public func copyPrevious(into slot: Slot, source: EntrySource = .app, now: Date = .now) -> Bool {
        guard let previous = previousLoggedSlot(before: slot) else { return false }
        return log(
            slot: slot,
            text: previous.text ?? "",
            category: previous.category,
            tagKeys: previous.tagKeys,
            source: source,
            now: now
        )
    }

    public func previousLoggedSlot(before slot: Slot) -> Slot? {
        guard let day = slot.day else { return nil }
        return day.orderedSlots
            .filter { $0.startAt < slot.startAt && $0.state == .logged }
            .last
    }

    /// Clears an entry back to pending. Only possible while the slot is still fillable —
    /// there is no way back from `unaccounted`.
    public func clear(slot: Slot, now: Date = .now) {
        guard slot.isFillable(at: now, backfillWindowMinutes: settings.backfillWindowMinutes) else { return }
        slot.text = nil
        slot.category = nil
        slot.tagKeys = []
        slot.state = .pending
        slot.loggedAt = nil
        slot.source = .app
        save()
        if let day = slot.day { refreshPrompts(for: day, now: now) }
    }

    public func assign(category: LogCategory?, to slot: Slot) {
        slot.category = category
        save()
    }

    public func slot(withID id: UUID) -> Slot? {
        let descriptor = FetchDescriptor<Slot>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first { $0.id == id }
    }

    // MARK: - Notification-driven entry points

    /// Handles a text reply typed straight into the banner.
    ///
    /// The reply carries no category, so the suggester fills one in from history — otherwise
    /// most entries would arrive uncategorised and the week view would say nothing. SPEC §5.4.
    public func logFromNotification(slotID: UUID, text: String, now: Date = .now) {
        guard let slot = slot(withID: slotID) else { return }
        log(slot: slot, text: text, category: nil, tagKeys: [], source: .notification, now: now)
    }

    public func copyPreviousFromNotification(slotID: UUID, now: Date = .now) {
        guard let slot = slot(withID: slotID) else { return }
        copyPrevious(into: slot, source: .notification, now: now)
    }

    private func suggestedCategory(for text: String) -> LogCategory? {
        let descriptor = FetchDescriptor<Slot>(sortBy: [SortDescriptor(\Slot.startAt, order: .reverse)])
        let recent = ((try? context.fetch(descriptor)) ?? []).filter { $0.state == .logged }
        return suggester.suggest(for: text, history: recent)?.category
    }

    // MARK: - Tags

    private func normalisedTagKeys(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for value in raw {
            let key = TextNormalizer.tagKey(value)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            keys.append(key)
        }
        return keys
    }

    private func recordTagUsage(_ keys: [String], displayNames: [String], now: Date) {
        guard !keys.isEmpty else { return }
        let existing = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var byKey: [String: Tag] = [:]
        for tag in existing { byKey[tag.key] = tag }

        for (index, key) in keys.enumerated() {
            if let tag = byKey[key] {
                tag.useCount += 1
                tag.lastUsedAt = now
            } else {
                let display = index < displayNames.count
                    ? displayNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    : key
                let tag = Tag(
                    key: key,
                    displayName: display.isEmpty ? key : display,
                    useCount: 1,
                    lastUsedAt: now
                )
                context.insert(tag)
            }
        }
    }

    public func allTags() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.useCount, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Block-outs

    public func allBlockOuts() -> [BlockOut] {
        let descriptor = FetchDescriptor<BlockOut>(sortBy: [SortDescriptor(\BlockOut.startAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    public func activeBlockOuts(now: Date = .now) -> [BlockOut] {
        allBlockOuts().filter { $0.cancelledAt == nil && $0.endAt > now }
    }

    public func currentBlockOut(now: Date = .now) -> BlockOut? {
        allBlockOuts().first { $0.isActive(at: now) }
    }

    /// Declares the next stretch of time in advance, pre-filling the slots it covers.
    ///
    /// Slots are materialised *past* `now` so the block can fill them and their prompts never
    /// get scheduled. `endDay` cleans up any that are still in the future when you finish.
    @discardableResult
    public func createBlockOut(
        minutes: Int,
        text: String,
        category: LogCategory?,
        now: Date = .now
    ) -> BlockOut? {
        guard minutes > 0 else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let day = activeDay else { return nil }

        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        let block = BlockOut(startAt: now, endAt: end, text: trimmed, category: category, createdAt: now)
        context.insert(block)

        materialiseSlots(for: day, through: end)

        for slot in day.slots where block.covers(slot: slot) && slot.state == .pending {
            apply(block: block, to: slot)
        }
        save()

        let cal = calendar(for: day)
        Task {
            await notifications.scheduleBlockEnd(at: end, label: trimmed, calendar: cal)
        }
        if let state = activityState(for: day, now: now) {
            activities.update(state)
        }
        refreshPrompts(for: day, now: now)
        return block
    }

    private func apply(block: BlockOut, to slot: Slot) {
        slot.text = block.text
        slot.category = block.category
        slot.state = .logged
        slot.source = .blockOut
        slot.loggedAt = block.createdAt
        notifications.cancelPrompts(forSlotID: slot.id)
    }

    /// Ends a block early. Slots it filled that haven't happened yet revert to pending —
    /// the block was a prediction, and it turned out wrong.
    public func cancelBlockOut(_ block: BlockOut, now: Date = .now) {
        block.cancelledAt = now
        if let day = activeDay {
            for slot in day.slots where slot.source == .blockOut && slot.endAt > now && block.covers(slot: slot) {
                slot.text = nil
                slot.category = nil
                slot.state = .pending
                slot.loggedAt = nil
                slot.source = .app
            }
            save()
            refreshPrompts(for: day, now: now)
            if let state = activityState(for: day, now: now) {
                activities.update(state)
            }
        } else {
            save()
        }
        notifications.cancelBlockEnd()
    }

    // MARK: - Live Activity state

    public func fillableSlots(now: Date = .now) -> [Slot] {
        guard let day = activeDay else { return [] }
        return reconciler.fillableSlots(in: day.slots, now: now)
    }

    private func activityState(for day: Day, now: Date) -> WUUTActivityAttributes.ContentState? {
        let ordered = day.orderedSlots
        guard let current = ordered.first(where: { $0.contains(now) }) ?? ordered.last else { return nil }

        let lastEntry = ordered
            .filter { $0.state == .logged && $0.text?.isEmpty == false }
            .last?
            .text

        let block = currentBlockOut(now: now)
        let fillable = reconciler.fillableSlots(in: day.slots, now: now)

        // The button acts on the oldest slot still waiting, falling back to the one running.
        let actionable = fillable.first ?? current
        let canRepeat = previousLoggedSlot(before: actionable) != nil

        return WUUTActivityAttributes.ContentState(
            slotStart: current.startAt,
            slotEnd: current.endAt,
            unloggedCount: fillable.count,
            lastEntry: lastEntry.map { String($0.prefix(60)) },
            blockedUntil: block?.endAt,
            blockedLabel: block?.text,
            accountedPercent: Int((day.accountedFraction * 100).rounded()),
            unaccountedMinutes: day.unaccountedMinutes,
            actionableSlotID: canRepeat ? actionable.id.uuidString : nil
        )
    }

    // MARK: - Summary

    /// The most recent day before `day` that actually recorded something.
    public func previousLoggedDay(before day: Day) -> Day? {
        allDays()
            .filter { $0.date < day.date && ($0.loggedMinutes + $0.unaccountedMinutes) > 0 }
            .max { $0.date < $1.date }
    }

    public struct DaySummary {
        public let title: String
        public let body: String
    }

    /// The day's one nudge. Real numbers, no configuration. SPEC §7.5.
    public func daySummary(for day: Day) -> DaySummary {
        let logged = day.loggedMinutes
        let unaccounted = day.unaccountedMinutes
        let categories = activeCategories()
        var namesByID: [UUID: String] = [:]
        for category in categories { namesByID[category.id] = category.name }

        let totals = day.minutesByCategory()
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { entry -> String? in
                guard let name = namesByID[entry.key] else { return nil }
                return "\(name) \(Formatters.duration(minutes: entry.value))"
            }

        // A percentage on its own says nothing. Comparison is the whole point of keeping
        // the record, so the headline carries it whenever there is a day to compare to.
        var title = "\(Formatters.percent(day.accountedFraction)) accounted for"
        if let change = DayStatistics.percentagePointChange(
            from: previousLoggedDay(before: day)?.accountedFraction,
            to: day.accountedFraction
        ), change != 0 {
            title += change > 0 ? ", up \(change) points" : ", down \(-change) points"
        }

        var parts: [String] = ["\(Formatters.duration(minutes: logged)) logged"]
        if unaccounted > 0 {
            parts.append("\(Formatters.duration(minutes: unaccounted)) unaccounted")
            let gap = day.longestGapMinutes
            if gap >= 30 {
                parts.append("longest gap \(Formatters.duration(minutes: gap))")
            }
        }
        if !totals.isEmpty {
            parts.append(totals.joined(separator: ", "))
        }
        return DaySummary(title: title, body: parts.joined(separator: " · "))
    }
}
