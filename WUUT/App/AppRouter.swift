import Foundation
import Observation

/// Cross-cutting navigation state.
///
/// Exists so that tapping a notification can open the log sheet for *that* slot: the delegate
/// runs outside the view tree, sets `pendingSlotID`, and `TodayView` picks it up.
@MainActor
@Observable
public final class AppRouter {

    public enum Tab: Hashable {
        case today
        case week
        case settings
    }

    public var selectedTab: Tab = .today

    /// Slot the user tapped a notification for. Cleared once the sheet is shown.
    public var pendingSlotID: UUID?

    /// Set when a notification action changed data while the app was in the background,
    /// so the visible day can refresh itself.
    public var dataChangedAt: Date?

    public init() {}

    public func openLogSheet(slotID: UUID) {
        selectedTab = .today
        pendingSlotID = slotID
    }
}
