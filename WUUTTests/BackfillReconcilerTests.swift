import SwiftData
import XCTest
@testable import WUUT

/// Locking is irreversible, so the boundary conditions here are the ones that decide whether
/// a real afternoon of your life becomes editable or permanently "unaccounted".
@MainActor
final class BackfillReconcilerTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        context = try makeInMemoryContext()
    }

    private func slot(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int) -> Slot {
        makeSlot(
            in: context,
            from: TestClock.date(2026, 9, 21, startHour, startMinute),
            to: TestClock.date(2026, 9, 21, endHour, endMinute)
        )
    }

    func testAFinishedSlotInsideTheWindowIsFillableNotExpired() {
        let target = slot(9, 0, 9, 15)
        let now = TestClock.date(2026, 9, 21, 10, 0)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        XCTAssertEqual(reconciler.fillableSlots(in: [target], now: now).count, 1)
        XCTAssertTrue(reconciler.expiredSlots(in: [target], now: now).isEmpty)
    }

    func testASlotExpiresExactlyAtTheEndOfItsWindow() {
        let target = slot(9, 0, 9, 15)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        // 09:15 + 2h = 11:15. One minute earlier it is still yours.
        XCTAssertTrue(
            reconciler.expiredSlots(in: [target], now: TestClock.date(2026, 9, 21, 11, 14)).isEmpty
        )
        XCTAssertEqual(
            reconciler.expiredSlots(in: [target], now: TestClock.date(2026, 9, 21, 11, 15)).count,
            1
        )
    }

    func testTheInProgressSlotIsNeverExpired() {
        let target = slot(9, 0, 9, 15)
        let now = TestClock.date(2026, 9, 21, 9, 7)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 0)

        XCTAssertTrue(reconciler.expiredSlots(in: [target], now: now).isEmpty)
        XCTAssertTrue(target.isFillable(at: now, backfillWindowMinutes: 0))
    }

    func testAFutureSlotIsNeverExpired() {
        let target = slot(14, 0, 14, 15)
        let now = TestClock.date(2026, 9, 21, 10, 0)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        XCTAssertTrue(reconciler.expiredSlots(in: [target], now: now).isEmpty)
    }

    func testAlreadyLoggedSlotsAreLeftAlone() {
        let target = slot(9, 0, 9, 15)
        target.state = .logged
        let now = TestClock.date(2026, 9, 21, 23, 0)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        XCTAssertTrue(reconciler.expiredSlots(in: [target], now: now).isEmpty)
        XCTAssertTrue(reconciler.fillableSlots(in: [target], now: now).isEmpty)
    }

    func testAnUnaccountedSlotCannotBeFilledAgain() {
        let target = slot(9, 0, 9, 15)
        target.state = .unaccounted
        let now = TestClock.date(2026, 9, 21, 9, 20)

        XCTAssertFalse(target.isFillable(at: now, backfillWindowMinutes: 120))
    }

    func testTheCatchUpQueueIsOldestFirst() {
        let later = slot(10, 0, 10, 15)
        let earlier = slot(9, 0, 9, 15)
        let now = TestClock.date(2026, 9, 21, 10, 30)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        let queue = reconciler.fillableSlots(in: [later, earlier], now: now)
        XCTAssertEqual(queue.map(\.startAt), [earlier.startAt, later.startAt])
    }

    /// What the notification window schedules against: the in-progress slot, anything still
    /// fillable, and everything still to come.
    func testPromptableIncludesFutureAndInProgressButNotExpired() {
        let expired = slot(6, 0, 6, 15)
        let fillable = slot(10, 0, 10, 15)
        let inProgress = slot(10, 30, 10, 45)
        let future = slot(14, 0, 14, 15)
        let now = TestClock.date(2026, 9, 21, 10, 35)
        let reconciler = BackfillReconciler(backfillWindowMinutes: 120)

        let promptable = reconciler.promptableSlots(
            in: [expired, fillable, inProgress, future],
            now: now
        )
        XCTAssertEqual(
            promptable.map(\.startAt),
            [fillable.startAt, inProgress.startAt, future.startAt]
        )
    }
}
