import Foundation

/// A slot's lifecycle.
///
/// `unaccounted` is terminal and deliberately irreversible: a lock you can undo is not a
/// lock, and the honesty of the record is the whole product. See SPEC §7.3.
public enum SlotState: String, Codable, CaseIterable, Sendable {
    case pending
    case logged
    case unaccounted
}

/// How an entry got made. Kept for its own sake — it is interesting to know how much of
/// your record you wrote from a notification banner versus reconstructed after the fact.
public enum EntrySource: String, Codable, CaseIterable, Sendable {
    case notification
    case app
    case backfill
    case blockOut
    case siri

    public var label: String {
        switch self {
        case .notification: return "Notification"
        case .app: return "In app"
        case .backfill: return "Backfilled"
        case .blockOut: return "Blocked out"
        case .siri: return "Siri"
        }
    }
}
