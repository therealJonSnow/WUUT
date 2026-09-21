import ActivityKit
import Foundation

/// Drives the lock-screen Live Activity.
///
/// Two details carry the whole thing (SPEC §6):
///
/// - The countdown is rendered with `Text(timerInterval:)` in the widget, so it keeps ticking
///   without the app running. Otherwise the lock screen would freeze between launches.
/// - `staleDate` is the end of the current slot, so an activity the app has failed to update
///   visibly goes stale rather than confidently showing you the wrong quarter hour.
///
/// Every entry point is a no-op when Live Activities are switched off or unavailable —
/// including on a free Personal Team, where this may simply not work. The app is fully
/// functional without it; the lock screen is a convenience, not the record.
@MainActor
public final class LiveActivityController {

    private let settings: AppSettings
    private var activity: Activity<WUUTActivityAttributes>?

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Re-adopts an activity started by a previous launch. Without this, relaunching would
    /// orphan the one already on the lock screen and start a second alongside it.
    public func adoptExisting() {
        if activity == nil {
            activity = Activity<WUUTActivityAttributes>.activities.first
        }
    }

    public func start(dayStart: Date, state: WUUTActivityAttributes.ContentState) {
        guard settings.liveActivityEnabled, isAvailable else { return }
        adoptExisting()
        if activity != nil {
            update(state)
            return
        }
        do {
            activity = try Activity.request(
                attributes: WUUTActivityAttributes(dayStart: dayStart),
                content: ActivityContent(state: state, staleDate: state.slotEnd),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    public func update(_ state: WUUTActivityAttributes.ContentState) {
        guard settings.liveActivityEnabled else { return }
        adoptExisting()
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: state.slotEnd))
        }
    }

    public func end() {
        adoptExisting()
        guard let current = activity else { return }
        activity = nil
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
        }
    }
}
