import SwiftData
import XCTest
@testable import WUUT

/// Guards the rule that everything else quietly depends on: metrics are duration-weighted,
/// never slot counts. A day with two short stubs must not report itself as if every slot were
/// a full quarter hour. See SPEC §3.2.
@MainActor
final class AggregationTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try makeInMemoryContext()
    }

    private func makeDay(startedAt: Date) -> Day {
        let day = Day(
            date: TestClock.calendar.startOfDay(for: startedAt),
            timeZoneIdentifier: "Europe/London",
            startedAt: startedAt
        )
        context.insert(day)
        return day
    }

    private func attach(
        _ day: Day,
        from start: Date,
        to end: Date,
        state: SlotState,
        category: LogCategory? = nil
    ) -> Slot {
        let slot = makeSlot(in: context, from: start, to: end, state: state)
        slot.category = category
        slot.day = day
        if state == .logged { slot.text = "something" }
        return slot
    }

    func testStubsContributeTheirRealLength() {
        let start = TestClock.date(2026, 9, 21, 7, 7)
        let day = makeDay(startedAt: start)

        // 8-minute opening stub, one full slot, 8-minute closing stub.
        _ = attach(day, from: start, to: TestClock.date(2026, 9, 21, 7, 15), state: .logged)
        _ = attach(
            day,
            from: TestClock.date(2026, 9, 21, 7, 15),
            to: TestClock.date(2026, 9, 21, 7, 30),
            state: .logged
        )
        _ = attach(
            day,
            from: TestClock.date(2026, 9, 21, 7, 30),
            to: TestClock.date(2026, 9, 21, 7, 38),
            state: .logged
        )

        // Counting slots would say 45 minutes. The truth is 31.
        XCTAssertEqual(day.loggedMinutes, 31)
        XCTAssertEqual(day.elapsedMinutes, 31)
    }

    func testAccountedFractionIgnoresStillPendingTime() {
        let start = TestClock.date(2026, 9, 21, 8, 0)
        let day = makeDay(startedAt: start)

        _ = attach(day, from: start, to: TestClock.date(2026, 9, 21, 8, 15), state: .logged)
        _ = attach(
            day,
            from: TestClock.date(2026, 9, 21, 8, 15),
            to: TestClock.date(2026, 9, 21, 8, 30),
            state: .unaccounted
        )
        _ = attach(
            day,
            from: TestClock.date(2026, 9, 21, 8, 30),
            to: TestClock.date(2026, 9, 21, 8, 45),
            state: .pending
        )

        // 15 logged of 30 settled. The pending slot is not yet a failure.
        XCTAssertEqual(day.accountedFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(day.pendingMinutes, 15)
    }

    func testAFreshDayIsNotZeroPercent() {
        let start = TestClock.date(2026, 9, 21, 8, 0)
        let day = makeDay(startedAt: start)
        _ = attach(day, from: start, to: TestClock.date(2026, 9, 21, 8, 15), state: .pending)

        XCTAssertEqual(day.accountedFraction, 1.0, accuracy: 0.0001)
    }

    func testCategoryMinutesAreDurationWeighted() {
        let start = TestClock.date(2026, 9, 21, 7, 7)
        let day = makeDay(startedAt: start)

        let work = LogCategory(
            name: "Work",
            colorHex: "1D4ED8",
            colorHexDark: "3C6BF1",
            symbolName: "laptopcomputer",
            sortOrder: 0
        )
        context.insert(work)

        _ = attach(day, from: start, to: TestClock.date(2026, 9, 21, 7, 15), state: .logged, category: work)
        _ = attach(
            day,
            from: TestClock.date(2026, 9, 21, 7, 15),
            to: TestClock.date(2026, 9, 21, 7, 30),
            state: .logged,
            category: work
        )

        XCTAssertEqual(day.minutesByCategory()[work.id], 23)
    }

    func testUncategorisedLoggedTimeIsReported() {
        let start = TestClock.date(2026, 9, 21, 8, 0)
        let day = makeDay(startedAt: start)
        _ = attach(day, from: start, to: TestClock.date(2026, 9, 21, 8, 15), state: .logged)

        XCTAssertEqual(day.uncategorisedMinutes, 15)
    }

    func testUnaccountedIsNotACategory() {
        XCTAssertFalse(DefaultCategories.all.contains { $0.name.lowercased() == "unaccounted" })
    }
}
