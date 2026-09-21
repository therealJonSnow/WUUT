import SwiftUI
import UIKit

extension Color {

    /// Six-digit hex, with or without a leading hash. Falls back to grey rather than
    /// trapping — a mistyped category colour should not be able to crash the app.
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }

        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }
}

extension LogCategory {
    /// Resolves per appearance at draw time, so a category keeps its identity in both light
    /// and dark without the view needing to know which is active.
    var color: Color {
        let light = colorHex
        let dark = colorHexDark
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

enum Theme {
    /// Colour for time that was never logged. Not a category — you can't assign it — so its
    /// colour lives here rather than in the store. See SPEC §4.1.
    static let unaccounted = Color.secondary.opacity(0.28)

    static let unaccountedSolid = Color(hex: "94A3B8")

    /// Row height for one quarter hour in the timeline.
    static let slotRowMinHeight: CGFloat = 52
}
