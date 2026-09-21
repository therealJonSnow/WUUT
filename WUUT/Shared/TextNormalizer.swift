import Foundation

/// Reduces entry text to a comparable key.
///
/// Used by `CategorySuggester` to recognise that "Walked the dog." and "walked the dog"
/// are the same activity. Deliberately crude: lowercase, strip punctuation, collapse
/// whitespace. Nothing stemmed, nothing learned.
public enum TextNormalizer {

    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let stripped = folded.unicodeScalars
            .map { scalar -> Character in
                if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
                return " "
            }
        return tokens(in: String(stripped)).joined(separator: " ")
    }

    /// Normalised words, in order, with duplicates preserved.
    public static func tokens(in text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Jaccard similarity of the two texts' word sets, in `0...1`.
    ///
    /// Word sets rather than sequences because "dog walk" and "walk the dog" should
    /// count as close, and because a short entry has too few words for order to mean much.
    public static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(tokens(in: normalize(lhs)))
        let right = Set(tokens(in: normalize(rhs)))
        if left.isEmpty || right.isEmpty { return 0 }
        let shared = left.intersection(right).count
        let total = left.union(right).count
        guard total > 0 else { return 0 }
        return Double(shared) / Double(total)
    }

    /// Normalises a tag to its storage key. Tags are matched case- and punctuation-insensitively.
    public static func tagKey(_ raw: String) -> String {
        normalize(raw).replacingOccurrences(of: " ", with: "-")
    }

    /// Splits a free-text tag field on commas, trimming and discarding blanks.
    public static func parseTagField(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
