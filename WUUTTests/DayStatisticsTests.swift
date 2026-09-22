import SwiftData
import XCTest
@testable import WUUT

/// The figures the app newly shows you. Each one exists because a number it replaced was
/// misleading, so the edge cases here are the point rather than decoration.
@MainActor
final class DayStatisticsTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try makeInMemoryContext()
    }

    private func slot(
        _ startHour: Int,
        _ startMinute: Int,
        _ endHour: Int,
        _ endMinute: Int,
        state: SlotState = .logged,
        source: EntrySource = .notification,
        loggedAfterMinutes: Int? = nil
    ) -> Slot {
        let s = makeSlot(
            in: context,
            from: TestClock.date(2026, 9, 21, startHour, startMinute),
            to: TestClock.date(2026, 9, 21, endHour, endMinute),
            state: state
        )
        s.source = source
        if state == .logged {
            s.text = "something"
            s.loggedAt = s.endAt.addingTimeInterval(TimeInterval((loggedAfterMinutes ?? 0) * 60))
        }
        return s
    }

    // MARK: - Longest gap

    /// The number this replaces: a total. Six scattered quarter hours and one long hole
    /// both come to 1h 30m, and they are completely different days.
    func testLongestGapFindsTheUnbrokenRun() {
        let slots = [
            slot(9, 0, 9, 15),
            slot(9, 15, 9, 30, state: .unaccounted),
            slot(9, 30, 9, 45, state: .unaccounted),
            slot(9, 45, 10, 0, state: .unaccounted),
            slot(10, 0, 10, 15),
            slot(10, 15, 10, 30, state: .unaccounted)
        ]
        // Four unaccounted slots, 60 minutes in total, but the longest run is 45.
        XCTAssertEqual(DayStatistics.longestGapMinutes(in: slots), 45)
    }

    func testLongestGapCountsStubsAtTheirRealLength() {
        let slots = [
            slot(7, 7, 7, 15, state: .unaccounted),
            slot(7, 15, 7, 30, state: .unaccounted)
        ]
        XCTAssertEqual(DayStatistics.longestGapMinutes(in: slots), 23)
    }

    func testLongestGapIsZeroWhenNothingIsMissing() {
        XCTAssertEqual(DayStatistics.longestGapMinutes(in: [slot(9, 0, 9, 15)]), 0)
    }

    func testLongestGapIgnoresSlotOrderAsGiven() {
        let later = slot(10, 0, 10, 15, state: .unaccounted)
        let earlier = slot(9, 45, 10, 0, state: .unaccounted)
        XCTAssertEqual(DayStatistics.longestGapMinutes(in: [later, earlier]), 30)
    }

    // MARK: - Provenance

    func testProvenanceCollapsesSourcesIntoThreeKinds() {
        XCTAssertEqual(DayStatistics.provenance(of: slot(9, 0, 9, 15, source: .notification)), .live)
        XCTAssertEqual(DayStatistics.provenance(of: slot(9, 0, 9, 15, source: .app)), .live)
        XCTAssertEqual(DayStatistics.provenance(of: slot(9, 0, 9, 15, source: .siri)), .live)
        XCTAssertEqual(DayStatistics.provenance(of: slot(9, 0, 9, 15, source: .blockOut)), .planned)
        XCTAssertEqual(DayStatistics.provenance(of: slot(9, 0, 9, 15, source: .backfill)), .reconstructed)
    }

    func testProvenanceMinutesAreDurationWeighted() {
        let slots = [
            slot(7, 7, 7, 15, source: .notification),   // 8 minutes
            slot(7, 15, 7, 30, source: .notification),  // 15
            slot(7, 30, 7, 45, source: .backfill),      // 15
            slot(7, 45, 8, 0, state: .pending)          // not logged, excluded
        ]
        let totals = DayStatistics.minutesByProvenance(in: slots)
        XCTAssertEqual(totals[.live], 23)
        XCTAssertEqual(totals[.reconstructed], 15)
        XCTAssertNil(totals[.planned])
    }

    // MARK: - Response time

    func testAnsweringDuringTheSlotCountsAsZeroNotNegative() {
        let early = slot(9, 0, 9, 15, loggedAfterMinutes: -10)
        XCTAssertEqual(DayStatistics.responseDelaysMinutes(in: [early]), [0])
    }

    /// A blocked-out slot was written before the fact and says nothing about how quickly
    /// you answer a prompt, so it must not drag the figure down.
    func testBlockedOutSlotsAreExcludedFromResponseTime() {
        let slots = [
            slot(9, 0, 9, 15, source: .blockOut, loggedAfterMinutes: -120),
            slot(9, 15, 9, 30, source: .notification, loggedAfterMinutes: 4)
        ]
        XCTAssertEqual(DayStatistics.responseDelaysMinutes(in: slots), [4])
    }

    /// Median rather than mean: one slot answered eleven hours late would make an average
    /// meaningless.
    func testMedianIgnoresOneWildlyLateEntry() {
        let slots = [
            slot(9, 0, 9, 15, loggedAfterMinutes: 2),
            slot(9, 15, 9, 30, loggedAfterMinutes: 3),
            slot(9, 30, 9, 45, loggedAfterMinutes: 660)
        ]
        XCTAssertEqual(DayStatistics.medianResponseMinutes(in: slots), 3)
    }

    func testMedianOfAnEvenCountAveragesTheMiddlePair() {
        let slots = [
            slot(9, 0, 9, 15, loggedAfterMinutes: 2),
            slot(9, 15, 9, 30, loggedAfterMinutes: 4),
            slot(9, 30, 9, 45, loggedAfterMinutes: 6),
            slot(9, 45, 10, 0, loggedAfterMinutes: 10)
        ]
        XCTAssertEqual(DayStatistics.medianResponseMinutes(in: slots), 5)
    }

    func testMedianIsNilWithNothingToMeasure() {
        XCTAssertNil(DayStatistics.medianResponseMinutes(in: [slot(9, 0, 9, 15, state: .pending)]))
    }

    // MARK: - Comparison

    /// Silence rather than a fabricated baseline: a first week has nothing to be up on.
    func testNoComparisonWithoutAPreviousPeriod() {
        XCTAssertNil(DayStatistics.percentagePointChange(from: nil, to: 0.76))
    }

    func testComparisonIsInWholePercentagePoints() {
        XCTAssertEqual(DayStatistics.percentagePointChange(from: 0.68, to: 0.76), 8)
        XCTAssertEqual(DayStatistics.percentagePointChange(from: 0.80, to: 0.76), -4)
        XCTAssertEqual(DayStatistics.percentagePointChange(from: 0.76, to: 0.76), 0)
    }

    func testAccountedFractionTreatsAnUnsettledDayAsWhole() {
        XCTAssertEqual(DayStatistics.accountedFraction(logged: 0, unaccounted: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(DayStatistics.accountedFraction(logged: 30, unaccounted: 10), 0.75, accuracy: 0.0001)
    }
}
