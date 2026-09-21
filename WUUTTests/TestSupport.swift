import Foundation
import SwiftData
import XCTest
@testable import WUUT

/// Fixed timezone so results don't depend on where the test runs.
/// Europe/London specifically, because it has DST and one test needs a transition.
enum TestClock {

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        _ second: Int = 0,
        calendar: Calendar = TestClock.calendar
    ) -> Date {
        let components = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
        guard let date = calendar.date(from: components) else {
            fatalError("Could not build \(year)-\(month)-\(day) \(hour):\(minute)")
        }
        return date
    }
}

/// In-memory store, so model objects behave as they do in the app without touching disk.
@MainActor
func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Day.self, Slot.self, LogCategory.self, Tag.self, BlockOut.self])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}

@MainActor
func makeSlot(
    in context: ModelContext,
    from start: Date,
    to end: Date,
    state: SlotState = .pending
) -> Slot {
    let slot = Slot(startAt: start, endAt: end, state: state)
    context.insert(slot)
    return slot
}
