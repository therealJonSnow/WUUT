import Foundation
import UserNotifications

/// Routes notification responses back into the model.
///
/// This is where the app earns its keep: a text reply typed into the banner is logged here
/// without the app ever coming to the foreground. Every path also re-runs `reconcile()`, which
/// tops up the rolling notification window — responding to a prompt is the most reliable wake
/// the app gets, so it is the most important place to refill. See SPEC §5.1.
public final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    public static let shared = NotificationDelegate()

    /// Show prompts even while the app is open — you might be looking at a different screen.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let actionIdentifier = response.actionIdentifier
        let typedText = (response as? UNTextInputNotificationResponse)?.userText

        // Prefer the identifier, fall back to userInfo — belt and braces, since losing the
        // slot reference would mean silently dropping something you took the trouble to type.
        let slotID = NotificationScheduler.slotID(fromIdentifier: request.identifier)
            ?? (request.content.userInfo[NotificationScheduler.userInfoSlotIDKey] as? String)
                .flatMap(UUID.init(uuidString:))

        Task { @MainActor in
            handle(slotID: slotID, actionIdentifier: actionIdentifier, typedText: typedText)
            completionHandler()
        }
    }

    @MainActor
    private func handle(slotID: UUID?, actionIdentifier: String, typedText: String?) {
        let container = AppContainer.shared
        let controller = container.dayController

        defer {
            controller.reconcile()
            container.router.dataChangedAt = .now
        }

        guard let slotID else { return }

        switch actionIdentifier {
        case NotificationScheduler.replyActionIdentifier:
            guard let text = typedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            controller.logFromNotification(slotID: slotID, text: text)

        case NotificationScheduler.sameAsLastActionIdentifier:
            controller.copyPreviousFromNotification(slotID: slotID)

        case UNNotificationDefaultActionIdentifier:
            container.router.openLogSheet(slotID: slotID)

        default:
            break
        }
    }
}
