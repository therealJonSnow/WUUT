import AppIntents
import Foundation

/// The lock-screen button: repeats your previous entry into the slot that is waiting.
///
/// This is the lowest-friction path the app has — a slot logged without unlocking the phone,
/// opening anything, or typing. For an app whose whole viability rests on friction, it is
/// worth the extra moving parts.
///
/// Compiled into **both** the app and the widget extension. The widget needs the type to
/// build the button; iOS runs `perform()` in the app's process, which is why the work is
/// behind `WUUTIntentHandler` — each target supplies its own, and the widget's does nothing.
/// App Intents need no paid entitlement, so this works on a free Apple ID.
struct LogSameAsLastIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Same as last"
    static var description = IntentDescription("Repeat the previous entry into the waiting slot.")

    /// Set from the Live Activity's current content state.
    @Parameter(title: "Slot")
    var slotID: String

    init() {}

    init(slotID: String) {
        self.slotID = slotID
    }

    func perform() async throws -> some IntentResult {
        await WUUTIntentHandler.logSameAsLast(slotID: slotID)
        return .result()
    }
}
