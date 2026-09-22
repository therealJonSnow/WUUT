import Foundation
import SwiftData

/// A top-level activity category.
///
/// Named `LogCategory` rather than `Category` to stay clear of type names in Charts and
/// UIKit — the schema is what matters, not the Swift identifier.
///
/// Archived rather than deleted, always: months-old entries have to keep meaning something.
@Model
public final class LogCategory {

    public var id: UUID = UUID()
    public var name: String = ""

    /// Six-digit hex, no leading hash. Light appearance.
    public var colorHex: String = "888888"

    /// Unused. The app is light-appearance only (see `Theme`), so nothing reads this.
    ///
    /// Kept in the schema rather than removed because dropping a stored property means
    /// migrating a store that holds the only copy of real logged data, which is not a
    /// trade worth making for a field nobody can see. It is written as a copy of
    /// `colorHex` so it is correct if dark mode is ever done properly.
    public var colorHexDark: String = "999999"

    /// SF Symbol name.
    public var symbolName: String = "circle"

    public var sortOrder: Int = 0
    public var isArchived: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        colorHexDark: String,
        symbolName: String,
        sortOrder: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.colorHexDark = colorHexDark
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}

/// The seed set, written on first launch and editable from Settings afterwards.
///
/// Note there is no "Unaccounted" category. Unaccounted time is the *absence* of a logged
/// slot, derived from `SlotState`, so it can never be assigned by hand — which is what stops
/// it from being quietly explained away.
///
/// Hues are assigned by meaning and only their lightness and chroma were optimised, against
/// the ivory page rather than a neutral white. Violet is excluded — it rules the page and
/// marks missing time, so no category may be mistaken for either.
///
/// The honest number: the weakest pair in this set is ΔE 7.7 in normal vision and 1.4 under
/// simulated colour blindness. Fourteen categories **cannot** be told apart by colour alone,
/// and no palette fixes that. It is why every appearance of a category in this app — chip,
/// bar, legend row — carries its symbol and its name, and why colour is only ever
/// reinforcement. Cutting the seeded set to about eight is the only thing that would make
/// colour self-sufficient.
public enum DefaultCategories {

    public static let all: [(name: String, colorHex: String, colorHexDark: String, symbolName: String)] = [
        ("Work",             "02589A", "02589A", "laptopcomputer"),   // ink blue
        ("Meetings",         "099EA0", "099EA0", "person.2.fill"),    // steel — off purple, violet owns it
        ("Admin",            "A07506", "A07506", "tray.full.fill"),   // filing-cabinet khaki
        ("Social media",     "993D6E", "993D6E", "iphone.gen3"),      // magenta
        ("Entertainment",    "AB5242", "AB5242", "tv.fill"),          // burnt orange
        ("Reading",          "03A567", "03A567", "book.fill"),        // library green
        ("Exercise",         "CC495F", "CC495F", "figure.run"),       // vermilion
        ("Dog",              "8B5505", "8B5505", "dog.fill"),         // ochre
        ("Chores",           "037C9A", "037C9A", "washer.fill"),      // slate
        ("Errands",          "018370", "018370", "bag.fill"),         // teal
        ("Eating",           "C57148", "C57148", "fork.knife"),       // sienna
        ("Family & friends", "AE5E8F", "AE5E8F", "person.3.fill"),    // rose
        ("Travel",           "0395D1", "0395D1", "tram.fill"),        // indigo
        ("Rest",             "70883D", "70883D", "moon.zzz.fill")     // sage
    ]

    public static func makeAll() -> [LogCategory] {
        all.enumerated().map { index, spec in
            LogCategory(
                name: spec.name,
                colorHex: spec.colorHex,
                colorHexDark: spec.colorHexDark,
                symbolName: spec.symbolName,
                sortOrder: index
            )
        }
    }

    /// Offered when you add a category of your own, cycling through the set.
    public static func colorPair(forSortOrder order: Int) -> (light: String, dark: String) {
        let spec = all[abs(order) % all.count]
        return (spec.colorHex, spec.colorHexDark)
    }
}
