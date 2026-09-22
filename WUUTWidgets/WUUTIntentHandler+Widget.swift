import Foundation

/// Widget-side stand-in so `LogSameAsLastIntent` compiles in this target.
///
/// Never executed: iOS performs a `LiveActivityIntent` in the host app's process, where the
/// app target's copy of this type does the work. It exists only so the extension does not
/// have to import SwiftData or the app's object graph.
enum WUUTIntentHandler {
    static func logSameAsLast(slotID: String) async {}
}
