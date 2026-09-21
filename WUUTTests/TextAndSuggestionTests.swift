import SwiftData
import XCTest
@testable import WUUT

final class TextNormalizerTests: XCTestCase {

    func testNormalizeLowercasesAndStripsPunctuation() {
        XCTAssertEqual(TextNormalizer.normalize("Walked the dog."), "walked the dog")
        XCTAssertEqual(TextNormalizer.normalize("  Email —  inbox zero!  "), "email inbox zero")
    }

    func testNormalizeFoldsDiacritics() {
        XCTAssertEqual(TextNormalizer.normalize("Café"), "cafe")
    }

    func testIdenticalTextIsFullySimilar() {
        XCTAssertEqual(TextNormalizer.similarity("walked the dog", "Walked the dog!"), 1.0, accuracy: 0.0001)
    }

    func testWordOrderDoesNotMatter() {
        XCTAssertEqual(TextNormalizer.similarity("dog walk", "walk dog"), 1.0, accuracy: 0.0001)
    }

    func testUnrelatedTextIsNotSimilar() {
        XCTAssertLessThan(TextNormalizer.similarity("walked the dog", "code review"), 0.2)
    }

    func testEmptyTextIsNeverSimilar() {
        XCTAssertEqual(TextNormalizer.similarity("", "anything"), 0)
    }

    func testTagKeyIsHyphenated() {
        XCTAssertEqual(TextNormalizer.tagKey("Deep Work"), "deep-work")
        XCTAssertEqual(TextNormalizer.tagKey("  side project! "), "side-project")
    }

    func testTagFieldSplitsOnCommas() {
        XCTAssertEqual(
            TextNormalizer.parseTagField("deep work, admin ,, email "),
            ["deep work", "admin", "email"]
        )
    }
}

/// The suggester exists because a reply typed into a notification banner has no category.
/// Without it, most entries would arrive uncategorised and the week view would say nothing.
@MainActor
final class CategorySuggesterTests: XCTestCase {

    private var context: ModelContext!
    private var dog: LogCategory!
    private var work: LogCategory!

    override func setUpWithError() throws {
        context = try makeInMemoryContext()
        dog = LogCategory(name: "Dog", colorHex: "B8860B", colorHexDark: "9D7001", symbolName: "dog.fill", sortOrder: 0)
        work = LogCategory(name: "Work", colorHex: "1D4ED8", colorHexDark: "3C6BF1", symbolName: "laptopcomputer", sortOrder: 1)
        context.insert(dog)
        context.insert(work)
    }

    private func logged(_ text: String, _ category: LogCategory, tags: [String] = []) -> Slot {
        let slot = makeSlot(
            in: context,
            from: TestClock.date(2026, 9, 21, 9, 0),
            to: TestClock.date(2026, 9, 21, 9, 15),
            state: .logged
        )
        slot.text = text
        slot.category = category
        slot.tagKeys = tags
        return slot
    }

    func testExactMatchWinsAndIsFlagged() {
        let history = [logged("Walked the dog", dog, tags: ["morning"])]
        let suggestion = CategorySuggester().suggest(for: "walked the dog!", history: history)

        XCTAssertEqual(suggestion?.category?.id, dog.id)
        XCTAssertEqual(suggestion?.tagKeys, ["morning"])
        XCTAssertEqual(suggestion?.isExactMatch, true)
    }

    func testCloseEnoughTextMatchesFuzzily() {
        let history = [logged("Walked the dog round the park", dog)]
        let suggestion = CategorySuggester(similarityThreshold: 0.5)
            .suggest(for: "Walked the dog round the block", history: history)

        XCTAssertEqual(suggestion?.category?.id, dog.id)
        XCTAssertEqual(suggestion?.isExactMatch, false)
    }

    func testDistantTextSuggestsNothing() {
        let history = [logged("Walked the dog", dog)]
        XCTAssertNil(CategorySuggester().suggest(for: "Refactored the parser", history: history))
    }

    func testMostRecentExactMatchWins() {
        // History arrives most-recent-first.
        let history = [logged("Standup", work), logged("Standup", dog)]
        let suggestion = CategorySuggester().suggest(for: "standup", history: history)

        XCTAssertEqual(suggestion?.category?.id, work.id)
    }

    func testEmptyTextSuggestsNothing() {
        let history = [logged("Walked the dog", dog)]
        XCTAssertNil(CategorySuggester().suggest(for: "   ", history: history))
    }

    func testUnloggedHistoryIsIgnored() {
        let slot = logged("Walked the dog", dog)
        slot.state = .pending
        XCTAssertNil(CategorySuggester().suggest(for: "Walked the dog", history: [slot]))
    }
}

final class NotificationIdentifierTests: XCTestCase {

    /// Identifiers are dot-separated because a UUID already contains hyphens — getting this
    /// wrong would mean a banner reply could not be matched back to its slot.
    func testSlotIdentifierRoundTrips() {
        let id = UUID()
        let identifier = NotificationScheduler.identifier(slotID: id, index: 2)
        XCTAssertEqual(NotificationScheduler.slotID(fromIdentifier: identifier), id)
    }

    func testForeignIdentifiersAreRejected() {
        XCTAssertNil(NotificationScheduler.slotID(fromIdentifier: "day-summary"))
        XCTAssertNil(NotificationScheduler.slotID(fromIdentifier: "block-end"))
        XCTAssertNil(NotificationScheduler.slotID(fromIdentifier: "slot.not-a-uuid.0"))
    }
}
