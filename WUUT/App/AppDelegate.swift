import UIKit
import UserNotifications

public final class AppDelegate: NSObject, UIApplicationDelegate {

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppSettings.registerDefaults()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Registration has to happen during launch or BGTaskScheduler traps.
        BackgroundRefresh.register()
        return true
    }
}
