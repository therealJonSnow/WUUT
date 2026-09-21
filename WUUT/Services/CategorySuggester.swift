import Foundation

/// Guesses a category for an entry from what you have written before.
///
/// This exists because of a hole the notification design opens up: replying from the banner
/// gives text but no category, and without a guess most entries would arrive uncategorised
/// and the week view would be meaningless. See SPEC §5.4.
///
/// A history lookup, not a model. An exact match on the normalised text wins outright;
/// failing that, the closest entry by word overlap wins if it clears `similarityThreshold`.
/// Your life is repetitive enough for that to work, which is rather the point of measuring it.
public struct CategorySuggester {

    /// Word-overlap floor for a fuzzy match. 0.6 means most of the words have to agree.
    public var similarityThreshold: Double

    /// How many past entries to consider, most recent first. Bounded so a year of history
    /// doesn't make every banner reply slow.
    public var historyLimit: Int

    public init(similarityThreshold: Double = 0.6, historyLimit: Int = 400) {
        self.similarityThreshold = similarityThreshold
        self.historyLimit = historyLimit
    }

    public struct Suggestion: Equatable {
        public let category: LogCategory?
        public let tagKeys: [String]
        public let isExactMatch: Bool
    }

    /// `history` should be logged slots, most recent first.
    public func suggest(for text: String, history: [Slot]) -> Suggestion? {
        let target = TextNormalizer.normalize(text)
        guard !target.isEmpty else { return nil }

        let candidates = history.prefix(historyLimit).filter {
            $0.state == .logged && $0.text?.isEmpty == false
        }

        // Exact normalised match, most recent wins.
        for slot in candidates {
            guard let slotText = slot.text else { continue }
            if TextNormalizer.normalize(slotText) == target {
                return Suggestion(category: slot.category, tagKeys: slot.tagKeys, isExactMatch: true)
            }
        }

        // Otherwise the closest by word overlap, if it is close enough.
        var best: (slot: Slot, score: Double)?
        for slot in candidates {
            guard let slotText = slot.text else { continue }
            let score = TextNormalizer.similarity(target, slotText)
            guard score >= similarityThreshold else { continue }
            if best == nil || score > best!.score {
                best = (slot, score)
            }
        }

        guard let match = best else { return nil }
        return Suggestion(category: match.slot.category, tagKeys: match.slot.tagKeys, isExactMatch: false)
    }
}
