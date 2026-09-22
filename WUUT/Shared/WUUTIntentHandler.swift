import Foundation

/// App-side implementation of the Live Activity button.
///
/// The widget extension compiles its own no-op copy of this type — see
/// `WUUTWidgets/WUUTIntentHandler+Widget.swift`. iOS performs a `LiveActivityIntent` in the
/// host app's process, so this is the one that actually runs.
enum WUUTIntentHandler {

    static func logSameAsLast(slotID: String) async {
        guard let uuid = UUID(uuidString: slotID) else { return }
        await MainActor.run {
            let controller = AppContainer.shared.dayController
            controller.copyPreviousFromNotification(slotID: uuid)
            controller.reconcile()
        }
    }
}
