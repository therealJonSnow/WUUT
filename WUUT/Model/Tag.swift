import Foundation
import SwiftData

/// A freeform tag, tracked for autocomplete and for the week's top-tags list.
///
/// The authoritative tags on an entry are `Slot.tagKeys`. This model is the index over them:
/// it exists to answer "what do I usually type" and "what did I tag most this week".
@Model
public final class Tag {

    public var id: UUID = UUID()

    /// Normalised key, e.g. `dog-walk`. Matching happens on this.
    public var key: String = ""

    /// What you actually typed, for display.
    public var displayName: String = ""

    public var useCount: Int = 0
    public var lastUsedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        key: String,
        displayName: String,
        useCount: Int = 0,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}
