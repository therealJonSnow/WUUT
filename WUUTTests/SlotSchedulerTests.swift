import XCTest
@testable import WUUT

/// The stub rules from SPEC §3.1, which every metric in the app depends on.
final class SlotSchedulerTests: XCTestCase {

    private let calendar = TestClock.calendar

    private func scheduler(minimumStub: Int = 3) -> SlotScheduler {
        SlotScheduler(calendar: calendar, minimumStubMinutes: minimumStub)
    }

    // MARK: - Opening stub

    func testFirstSlotRunsToTheNextQuarterHour() {
        let start = TestClock.date(2026, 9, 21, 7, 7)
        let plans = scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 21, 7, 20))

        XCTAssertEqual(plans.first?.startAt, start)
        XCTAssertEqual(plans.first?.endAt, TestClock.date(2026, 9, 21, 7, 15))
        XCTAssertEqual(plans.first?.durationMinutes, 8)
    }

    func testSlotsAfterTheStubAreAligned() {
        let start = TestClock.date(2026, 9, 21, 7, 7)
        let plans = scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 21, 8, 5))

        XCTAssertEqual(plans.count, 5)
        XCTAssertEqual(plans[1].startAt, TestClock.date(2026, 9, 21, 7, 15))
        XCTAssertEqual(plans[1].endAt, TestClock.date(2026, 9, 21, 7, 30))
        XCTAssertEqual(plans[2].endAt, TestClock.date(2026, 9, 21, 7, 45))
        XCTAssertEqual(plans[3].endAt, TestClock.date(2026, 9, 21, 8, 0))
        for plan in plans.dropFirst() {
            XCTAssertEqual(plan.durationMinutes, 15)
        }
    }

    func testStartingExactlyOnABoundaryProducesNoStub() {
        let start = TestClock.date(2026, 9, 21, 7, 15)
        let plans = scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 21, 7, 40))

        XCTAssertEqual(plans.first?.startAt, start)
        XCTAssertEqual(plans.first?.endAt, TestClock.date(2026, 9, 21, 7, 30))
        XCTAssertEqual(plans.first?.durationMinutes, 15)
    }

    /// Start at 07:14 and the stub would be one minute. It gets absorbed instead, so the
    /// first slot runs 07:14 → 07:30.
    func testTooShortAStubIsAbsorbedIntoTheFollowingSlot() {
        let start = TestClock.date(2026, 9, 21, 7, 14)
        let plans = scheduler(minimumStub: 3).slots(
            dayStart: start,
            through: TestClock.date(2026, 9, 21, 7, 40)
        )

        XCTAssertEqual(plans.first?.startAt, start)
        XCTAssertEqual(plans.first?.endAt, TestClock.date(2026, 9, 21, 7, 30))
        XCTAssertEqual(plans.first?.durationMinutes, 16)
    }

    func testStubIsKeptWhenItClearsTheMinimum() {
        let start = TestClock.date(2026, 9, 21, 7, 11)
        let plans = scheduler(minimumStub: 3).slots(
            dayStart: start,
            through: TestClock.date(2026, 9, 21, 7, 20)
        )
        XCTAssertEqual(plans.first?.endAt, TestClock.date(2026, 9, 21, 7, 15))
        XCTAssertEqual(plans.first?.durationMinutes, 4)
    }

    // MARK: - The in-progress slot

    func testTheSlotContainingNowIsIncluded() {
        let start = TestClock.date(2026, 9, 21, 7, 0)
        let plans = scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 21, 7, 20))

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans.last?.startAt, TestClock.date(2026, 9, 21, 7, 15))
        XCTAssertEqual(plans.last?.endAt, TestClock.date(2026, 9, 21, 7, 30))
    }

    func testNoSlotsBeforeTheDayStarts() {
        let start = TestClock.date(2026, 9, 21, 7, 0)
        XCTAssertTrue(
            scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 21, 6, 59)).isEmpty
        )
    }

    // MARK: - Closing stub

    func testTruncationProducesAClosingStub() {
        let start = TestClock.date(2026, 9, 21, 7, 0)
        let plan = scheduler().truncation(
            dayStart: start,
            endingAt: TestClock.date(2026, 9, 21, 22, 38)
        )

        XCTAssertEqual(plan?.startAt, TestClock.date(2026, 9, 21, 22, 30))
        XCTAssertEqual(plan?.endAt, TestClock.date(2026, 9, 21, 22, 38))
        XCTAssertEqual(plan?.durationMinutes, 8)
    }

    func testTooShortAClosingStubIsDropped() {
        let start = TestClock.date(2026, 9, 21, 7, 0)
        XCTAssertNil(
            scheduler(minimumStub: 3).truncation(
                dayStart: start,
                endingAt: TestClock.date(2026, 9, 21, 22, 31)
            )
        )
    }

    func testEndingOnABoundaryKeepsAWholeFinalSlot() {
        let start = TestClock.date(2026, 9, 21, 7, 0)
        let plan = scheduler().truncation(
            dayStart: start,
            endingAt: TestClock.date(2026, 9, 21, 22, 30)
        )
        XCTAssertEqual(plan?.durationMinutes, 15)
    }

    // MARK: - Past midnight

    /// A logical day is not a calendar day. An evening that runs to 01:30 keeps producing
    /// slots, and they stay attached to the day that started them.
    func testADayCanRunPastMidnight() {
        let start = TestClock.date(2026, 9, 21, 22, 0)
        let plans = scheduler().slots(dayStart: start, through: TestClock.date(2026, 9, 22, 1, 20))

        XCTAssertEqual(plans.first?.startAt, start)
        XCTAssertEqual(plans.last?.startAt, TestClock.date(2026, 9, 22, 1, 15))
        XCTAssertEqual(plans.count, 14)
    }

    // MARK: - Auto end

    func testAutoEndPicksTheNextOccurrenceOfTheHour() {
        let start = TestClock.date(2026, 9, 21, 7, 30)
        XCTAssertEqual(
            scheduler().autoEndDate(startedAt: start, hour: 2),
            TestClock.date(2026, 9, 22, 2, 0)
        )
    }

    /// Someone starting at 00:30 must not be cut off ninety minutes later.
    func testAutoEndPushesADayWhenTheCutoffIsTooSoon() {
        let start = TestClock.date(2026, 9, 21, 0, 30)
        XCTAssertEqual(
            scheduler().autoEndDate(startedAt: start, hour: 2, minimumDayHours: 4),
            TestClock.date(2026, 9, 22, 2, 0)
        )
    }

    // MARK: - Notification window

    func testUpcomingBoundariesAreAlignedAndStrictlyAhead() {
        let start = TestClock.date(2026, 9, 21, 7, 7)
        let now = TestClock.date(2026, 9, 21, 7, 20)
        let boundaries = scheduler().upcomingBoundaries(dayStart: start, after: now, limit: 4)

        XCTAssertEqual(boundaries.count, 4)
        XCTAssertEqual(boundaries[0], TestClock.date(2026, 9, 21, 7, 30))
        XCTAssertEqual(boundaries[3], TestClock.date(2026, 9, 21, 8, 15))
        for boundary in boundaries {
            XCTAssertGreaterThan(boundary, now)
        }
    }

    /// 18 slots at three prompts each is 54 pending requests, which has to stay under the
    /// platform's hard limit of 64. See SPEC §5.1.
    func testDefaultWindowStaysUnderThePlatformLimit() {
        let promptsPerSlot = 3
        let windowSlots = 18
        XCTAssertLessThan(
            windowSlots * promptsPerSlot,
            NotificationScheduler.platformPendingLimit
        )
    }
}
