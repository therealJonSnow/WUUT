import BackgroundTasks
import Foundation

/// Backstop for the rolling notification window.
///
/// The window normally gets topped up whenever you touch the app or answer a prompt, which
/// covers almost every case. This exists for the one that isn't covered: a phone left alone
/// long enough for 4.5 hours of scheduled prompts to run out. Best-effort by nature — iOS
/// decides whether and when to run it — so nothing depends on it.
public enum BackgroundRefresh {

    public static let taskIdentifier = "com.wuut.app.refresh"

    /// Must be called before the app finishes launching, or iOS traps.
    public static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handle(task: task)
        }
    }

    public static func schedule(after interval: TimeInterval = 30 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGTask) {
        // Always queue the next one first: an early return would end the chain for good.
        schedule()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            AppContainer.shared.dayController.reconcile()
            AppContainer.shared.backup.runWeeklyBackupIfDue()
            task.setTaskCompleted(success: true)
        }
    }
}
