import Foundation

/// UserDefaults keys, shared between this type and the `@AppStorage` bindings in Settings.
public enum SettingsKey {
    public static let minimumStubMinutes = "settings.minimumStubMinutes"
    public static let backfillWindowMinutes = "settings.backfillWindowMinutes"
    public static let autoEndHour = "settings.autoEndHour"
    public static let firstFollowUpMinutes = "settings.firstFollowUpMinutes"
    public static let secondFollowUpMinutes = "settings.secondFollowUpMinutes"
    public static let promptWindowSlotCount = "settings.promptWindowSlotCount"
    public static let useTimeSensitive = "settings.useTimeSensitive"
    public static let daySummaryEnabled = "settings.daySummaryEnabled"
    public static let liveActivityEnabled = "settings.liveActivityEnabled"
    public static let backupFolderBookmark = "settings.backupFolderBookmark"
    public static let lastBackupAt = "settings.lastBackupAt"
    public static let didSeedCategories = "settings.didSeedCategories"
}

/// Plain UserDefaults wrapper, deliberately not `@Observable`.
///
/// Services read it; the Settings screen writes the same keys through `@AppStorage`, which
/// gives SwiftUI its updates without this type needing to participate in observation.
public final class AppSettings {

    public static let shared = AppSettings()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call once at launch, before anything reads a value.
    public static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            SettingsKey.minimumStubMinutes: 3,
            SettingsKey.backfillWindowMinutes: 120,
            SettingsKey.autoEndHour: 2,
            SettingsKey.firstFollowUpMinutes: 5,
            SettingsKey.secondFollowUpMinutes: 11,
            SettingsKey.promptWindowSlotCount: 18,
            SettingsKey.useTimeSensitive: true,
            SettingsKey.daySummaryEnabled: true,
            SettingsKey.liveActivityEnabled: true
        ])
    }

    /// Shortest opening or closing stub worth creating. See SPEC §3.1.
    public var minimumStubMinutes: Int {
        get { defaults.integer(forKey: SettingsKey.minimumStubMinutes) }
        set { defaults.set(newValue, forKey: SettingsKey.minimumStubMinutes) }
    }

    /// How long a finished slot stays fillable before it locks as Unaccounted.
    public var backfillWindowMinutes: Int {
        get { defaults.integer(forKey: SettingsKey.backfillWindowMinutes) }
        set { defaults.set(newValue, forKey: SettingsKey.backfillWindowMinutes) }
    }

    /// Hour of the night a forgotten day gets closed at.
    public var autoEndHour: Int {
        get { defaults.integer(forKey: SettingsKey.autoEndHour) }
        set { defaults.set(newValue, forKey: SettingsKey.autoEndHour) }
    }

    public var firstFollowUpMinutes: Int {
        get { defaults.integer(forKey: SettingsKey.firstFollowUpMinutes) }
        set { defaults.set(newValue, forKey: SettingsKey.firstFollowUpMinutes) }
    }

    public var secondFollowUpMinutes: Int {
        get { defaults.integer(forKey: SettingsKey.secondFollowUpMinutes) }
        set { defaults.set(newValue, forKey: SettingsKey.secondFollowUpMinutes) }
    }

    /// Offsets, in seconds from the slot boundary, at which the three prompts fire.
    /// The escalation is the point of the app; the exact numbers are a guess, hence Settings.
    public var promptOffsets: [TimeInterval] {
        var offsets: [TimeInterval] = [0]
        let first = firstFollowUpMinutes
        let second = secondFollowUpMinutes
        if first > 0 { offsets.append(TimeInterval(first * 60)) }
        if second > first { offsets.append(TimeInterval(second * 60)) }
        return offsets
    }

    /// Slots covered by the rolling notification window. 18 slots x 3 prompts = 54 pending
    /// requests, under the iOS limit of 64 with headroom for summaries. See SPEC §5.1.
    public var promptWindowSlotCount: Int {
        get { defaults.integer(forKey: SettingsKey.promptWindowSlotCount) }
        set { defaults.set(newValue, forKey: SettingsKey.promptWindowSlotCount) }
    }

    /// Request `.timeSensitive` so prompts break through Focus. Needs an entitlement that may
    /// not be available on a free Personal Team; turn this off if prompts misbehave.
    public var useTimeSensitive: Bool {
        get { defaults.bool(forKey: SettingsKey.useTimeSensitive) }
        set { defaults.set(newValue, forKey: SettingsKey.useTimeSensitive) }
    }

    public var daySummaryEnabled: Bool {
        get { defaults.bool(forKey: SettingsKey.daySummaryEnabled) }
        set { defaults.set(newValue, forKey: SettingsKey.daySummaryEnabled) }
    }

    public var liveActivityEnabled: Bool {
        get { defaults.bool(forKey: SettingsKey.liveActivityEnabled) }
        set { defaults.set(newValue, forKey: SettingsKey.liveActivityEnabled) }
    }

    /// Security-scoped bookmark to the folder chosen for automatic weekly backups.
    /// A bookmark rather than an iCloud container, because CloudKit needs a paid account.
    public var backupFolderBookmark: Data? {
        get { defaults.data(forKey: SettingsKey.backupFolderBookmark) }
        set { defaults.set(newValue, forKey: SettingsKey.backupFolderBookmark) }
    }

    public var lastBackupAt: Date? {
        get { defaults.object(forKey: SettingsKey.lastBackupAt) as? Date }
        set { defaults.set(newValue, forKey: SettingsKey.lastBackupAt) }
    }

    public var didSeedCategories: Bool {
        get { defaults.bool(forKey: SettingsKey.didSeedCategories) }
        set { defaults.set(newValue, forKey: SettingsKey.didSeedCategories) }
    }
}
