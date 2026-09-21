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

    /// Dark-appearance hex.
    ///
    /// A second value rather than an automatic lightening of the first: the usable lightness
    /// band on a dark surface is narrower than on a light one, so a flipped colour either
    /// loses contrast or blows out. These were derived by retuning each hue's lightness into
    /// the dark band and checked against it.
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
/// On the colours: these were checked with a palette validator rather than picked by eye, in
/// both appearances, for lightness band, chroma floor, colour-blind separation and contrast
/// against the surface. The first attempt had Work and Meetings six units apart — effectively
/// the same colour, for the two categories a working day is mostly made of — and four
/// categories that read as grey, which is reserved here for unaccounted time.
///
/// Fourteen hues cannot all be mutually distinguishable, particularly in dark mode where the
/// usable lightness band is narrow. That is why no chart in this app identifies a category by
/// colour alone: every bar, chip and legend row carries the category's symbol and name. See
/// `WeekView`.
public enum DefaultCategories {

    public static let all: [(name: String, colorHex: String, colorHexDark: String, symbolName: String)] = [
        ("Work",             "1D4ED8", "3C6BF1", "laptopcomputer"),
        ("Meetings",         "A21CAF", "BB20CA", "person.2.fill"),
        ("Admin",            "B45309", "BD5709", "tray.full.fill"),
        ("Social media",     "DB2777", "D61D6F", "iphone.gen3"),
        ("Entertainment",    "0891B2", "0386A5", "tv.fill"),
        ("Reading",          "15803D", "029238", "book.fill"),
        ("Exercise",         "E11D48", "DD1641", "figure.run"),
        ("Dog",              "B8860B", "9D7001", "dog.fill"),
        ("Chores",           "7C3AED", "8849F4", "washer.fill"),
        ("Errands",          "0D9488", "019386", "bag.fill"),
        ("Eating",           "EA580C", "CA4805", "fork.knife"),
        ("Family & friends", "4338CA", "6C63E1", "person.3.fill"),
        ("Travel",           "0284C7", "0281C2", "tram.fill"),
        ("Rest",             "9A3412", "D53601", "moon.zzz.fill")
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

    /// Offered when you add a category of your own, cycling through the validated hues.
    public static func colorPair(forSortOrder order: Int) -> (light: String, dark: String) {
        let spec = all[abs(order) % all.count]
        return (spec.colorHex, spec.colorHexDark)
    }
}
