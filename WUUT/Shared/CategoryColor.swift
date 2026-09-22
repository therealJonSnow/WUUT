import SwiftUI

/// Kept apart from `Theme` because the widget extension compiles `Theme.swift` and must
/// not pull the SwiftData model in with it.
extension LogCategory {
    /// Light appearance only. See `Theme` on why there is no dark variant.
    var color: Color { Color(hex: colorHex) }
}
