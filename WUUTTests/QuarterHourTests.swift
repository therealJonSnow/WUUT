import XCTest
@testable import WUUT

final class QuarterHourTests: XCTestCase {

    private let calendar = TestClock.calendar

    func testFloorRoundsDownToQuarter() {
        let date = TestClock.date(2026, 9, 21, 7, 7, 42)
        XCTAssertEqual(
            QuarterHour.floor(date, calendar: calendar),
            TestClock.date(2026, 9, 21, 7, 0)
        )
    }

    func testFloorLeavesABoundaryAlone() {
        let boundary = TestClock.date(2026, 9, 21, 7, 45)
        XCTAssertEqual(QuarterHour.floor(boundary, calendar: calendar), boundary)
    }

    func testFloorDiscardsSeconds() {
        let date = TestClock.date(2026, 9, 21, 7, 30, 59)
        XCTAssertEqual(
            QuarterHour.floor(date, calendar: calendar),
            TestClock.date(2026, 9, 21, 7, 30)
        )
    }

    /// The strictness matters: a slot starting exactly on a boundary has to end on the *next*
    /// one, not on itself, or it would be zero minutes long.
    func testNextIsStrictlyAfterEvenOnABoundary() {
        let boundary = TestClock.date(2026, 9, 21, 7, 30)
        XCTAssertEqual(
            QuarterHour.next(after: boundary, calendar: calendar),
            TestClock.date(2026, 9, 21, 7, 45)
        )
    }

    func testNextFromMidQuarter() {
        XCTAssertEqual(
            QuarterHour.next(after: TestClock.date(2026, 9, 21, 7, 7), calendar: calendar),
            TestClock.date(2026, 9, 21, 7, 15)
        )
    }

    func testNextRollsOverTheHour() {
        XCTAssertEqual(
            QuarterHour.next(after: TestClock.date(2026, 9, 21, 7, 52), calendar: calendar),
            TestClock.date(2026, 9, 21, 8, 0)
        )
    }

    func testNextRollsOverMidnight() {
        XCTAssertEqual(
            QuarterHour.next(after: TestClock.date(2026, 9, 21, 23, 50), calendar: calendar),
            TestClock.date(2026, 9, 22, 0, 0)
        )
    }

    func testNextOccurrenceOfHourSkipsToTomorrowWhenPast() {
        let morning = TestClock.date(2026, 9, 21, 7, 0)
        XCTAssertEqual(
            QuarterHour.nextOccurrence(ofHour: 2, after: morning, calendar: calendar),
            TestClock.date(2026, 9, 22, 2, 0)
        )
    }

    func testNextOccurrenceOfHourStaysTodayWhenStillAhead() {
        let midnight = TestClock.date(2026, 9, 21, 0, 30)
        XCTAssertEqual(
            QuarterHour.nextOccurrence(ofHour: 2, after: midnight, calendar: calendar),
            TestClock.date(2026, 9, 21, 2, 0)
        )
    }

    /// Britain's clocks go forward at 01:00 on 29 March 2026. Advancing across it must give
    /// the honest wall-clock answer rather than a naive +15 minutes.
    func testAdvanceAcrossSpringForward() {
        let before = TestClock.date(2026, 3, 29, 0, 45)
        let after = QuarterHour.advance(before, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: after)
        XCTAssertEqual(components.hour, 2)
        XCTAssertEqual(components.minute, 0)
    }
}
