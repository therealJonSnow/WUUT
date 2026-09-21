import Foundation
import SwiftData

/// A stretch of time declared in advance — a meeting, a drive, the gym.
///
/// Pre-fills the slots it covers and suppresses their prompts. It is a prediction, not a
/// claim: any slot it filled can still be overwritten afterwards.
@Model
public final class BlockOut {

    public var id: UUID = UUID()
    public var startAt: Date = Date.distantPast
    public var endAt: Date = Date.distantPast
    public var text: String = ""
    public var category: LogCategory?
    public var createdAt: Date = Date.distantPast

    /// Cleared when you cancel the block early, so it stops suppressing prompts.
    public var cancelledAt: Date?

    public init(
        id: UUID = UUID(),
        startAt: Date,
        endAt: Date,
        text: String,
        category: LogCategory? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.text = text
        self.category = category
        self.createdAt = createdAt
    }

    public func isActive(at now: Date) -> Bool {
        cancelledAt == nil && now >= startAt && now < endAt
    }

    /// A slot belongs to the block if its midpoint falls inside it — so a slot the block
    /// only clips at the edge is left for you to answer normally.
    public func covers(slot: Slot) -> Bool {
        let midpoint = slot.startAt.addingTimeInterval(slot.endAt.timeIntervalSince(slot.startAt) / 2)
        return midpoint >= startAt && midpoint < endAt
    }
}
