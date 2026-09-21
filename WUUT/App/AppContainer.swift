import Foundation
import SwiftData

/// Single place the app's long-lived objects are built.
///
/// A container rather than environment plumbing because the notification delegate and the
/// background-refresh task both need the same `DayController`, and neither of them sits inside
/// the SwiftUI view tree.
@MainActor
public final class AppContainer {

    public static let shared = AppContainer()

    public let modelContainer: ModelContainer
    public let settings: AppSettings
    public let notifications: NotificationScheduler
    public let activities: LiveActivityController
    public let dayController: DayController
    public let backup: BackupService
    public let router: AppRouter

    /// Set when the on-disk store could not be opened and the app fell back to memory.
    /// Surfaced loudly in the UI — silently accepting a throwaway store would be the one
    /// failure mode that actually loses your history.
    public private(set) var storeFailureMessage: String?

    private init() {
        AppSettings.registerDefaults()
        let settings = AppSettings.shared
        self.settings = settings

        let schema = Schema([
            Day.self,
            Slot.self,
            LogCategory.self,
            Tag.self,
            BlockOut.self
        ])

        var container: ModelContainer
        var failure: String?
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration("WUUT", schema: schema)
            )
        } catch {
            failure = """
                The database could not be opened, so this session is running in memory only \
                and nothing you log will be kept. Restore your most recent backup from \
                Settings once the app launches normally. (\(error.localizedDescription))
                """
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
            } catch let fallbackError {
                // Both the on-disk and the in-memory store failed, which means the schema
                // itself is invalid rather than the file being unreadable. There is no
                // running from that, so fail with something legible in the crash log
                // instead of a bare trap.
                fatalError(
                    """
                    WUUT could not build its data model at all.
                    On-disk store: \(error)
                    In-memory store: \(fallbackError)
                    """
                )
            }
        }
        self.modelContainer = container
        self.storeFailureMessage = failure

        let context = container.mainContext
        let notifications = NotificationScheduler(settings: settings)
        let activities = LiveActivityController(settings: settings)

        self.notifications = notifications
        self.activities = activities
        self.backup = BackupService(context: context, settings: settings)
        self.router = AppRouter()
        self.dayController = DayController(
            context: context,
            settings: settings,
            notifications: notifications,
            activities: activities
        )
    }
}
