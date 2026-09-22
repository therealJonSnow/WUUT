import Foundation
import SwiftData

/// Export, import, and the automatic weekly backup.
///
/// The weekly backup writes into a folder you pick once — typically somewhere in iCloud Drive
/// — held as a security-scoped bookmark. A bookmark rather than an iCloud container because
/// CloudKit needs a paid developer account. See SPEC §8 and §9.2.
@MainActor
public final class BackupService {

    public enum BackupError: LocalizedError {
        case noFolderChosen
        case bookmarkStale
        case couldNotAccessFolder

        public var errorDescription: String? {
            switch self {
            case .noFolderChosen:
                return "No backup folder has been chosen yet."
            case .bookmarkStale:
                return "The backup folder moved. Choose it again."
            case .couldNotAccessFolder:
                return "Could not get permission to write to the backup folder."
            }
        }
    }

    public struct ImportSummary {
        public var daysAdded: Int
        public var daysUpdated: Int
        public var categoriesAdded: Int
        public var slotsAdded: Int
    }

    /// How many weekly backups to keep before the oldest is pruned.
    private let retainedBackupCount = 8

    private let context: ModelContext
    private let settings: AppSettings

    public init(context: ModelContext, settings: AppSettings = .shared) {
        self.context = context
        self.settings = settings
    }

    // MARK: - Encoding

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func buildDocument(now: Date = .now) -> ExportDocument {
        let categories = (try? context.fetch(FetchDescriptor<LogCategory>())) ?? []
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        let days = (try? context.fetch(FetchDescriptor<Day>())) ?? []

        return ExportDocument(
            exportedAt: now,
            categories: categories.map {
                ExportCategory(
                    id: $0.id,
                    name: $0.name,
                    colorHex: $0.colorHex,
                    colorHexDark: $0.colorHexDark,
                    symbolName: $0.symbolName,
                    sortOrder: $0.sortOrder,
                    isArchived: $0.isArchived
                )
            },
            tags: tags.map {
                ExportTag(
                    id: $0.id,
                    key: $0.key,
                    displayName: $0.displayName,
                    useCount: $0.useCount,
                    lastUsedAt: $0.lastUsedAt
                )
            },
            days: days
                .sorted { $0.date < $1.date }
                .map { day in
                    ExportDay(
                        id: day.id,
                        date: day.date,
                        timeZoneIdentifier: day.timeZoneIdentifier,
                        startedAt: day.startedAt,
                        endedAt: day.endedAt,
                        endedAutomatically: day.endedAutomatically,
                        slots: day.orderedSlots.map { slot in
                            ExportSlot(
                                id: slot.id,
                                startAt: slot.startAt,
                                endAt: slot.endAt,
                                text: slot.text,
                                categoryID: slot.category?.id,
                                tagKeys: slot.tagKeys,
                                state: slot.stateRaw,
                                source: slot.sourceRaw,
                                loggedAt: slot.loggedAt
                            )
                        }
                    )
                }
        )
    }

    public func exportData(now: Date = .now) throws -> Data {
        try encoder.encode(buildDocument(now: now))
    }

    /// Writes an export into the app's temp directory for the share sheet to pick up.
    public func exportToTemporaryFile(now: Date = .now) throws -> URL {
        let data = try exportData(now: now)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: now))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    /// Merges an export back in, matching on UUID so restoring is never destructive.
    @discardableResult
    public func importData(_ data: Data) throws -> ImportSummary {
        let document = try decoder.decode(ExportDocument.self, from: data)

        var summary = ImportSummary(daysAdded: 0, daysUpdated: 0, categoriesAdded: 0, slotsAdded: 0)

        // Categories first: slots reference them.
        var categoriesByID: [UUID: LogCategory] = [:]
        for category in (try? context.fetch(FetchDescriptor<LogCategory>())) ?? [] {
            categoriesByID[category.id] = category
        }
        for incoming in document.categories where categoriesByID[incoming.id] == nil {
            let category = LogCategory(
                id: incoming.id,
                name: incoming.name,
                colorHex: incoming.colorHex,
                colorHexDark: incoming.colorHexDark ?? incoming.colorHex,
                symbolName: incoming.symbolName,
                sortOrder: incoming.sortOrder,
                isArchived: incoming.isArchived
            )
            context.insert(category)
            categoriesByID[incoming.id] = category
            summary.categoriesAdded += 1
        }

        var tagsByKey: [String: Tag] = [:]
        for tag in (try? context.fetch(FetchDescriptor<Tag>())) ?? [] {
            tagsByKey[tag.key] = tag
        }
        for incoming in document.tags where tagsByKey[incoming.key] == nil {
            let tag = Tag(
                id: incoming.id,
                key: incoming.key,
                displayName: incoming.displayName,
                useCount: incoming.useCount,
                lastUsedAt: incoming.lastUsedAt
            )
            context.insert(tag)
            tagsByKey[incoming.key] = tag
        }

        var daysByID: [UUID: Day] = [:]
        for day in (try? context.fetch(FetchDescriptor<Day>())) ?? [] {
            daysByID[day.id] = day
        }

        for incoming in document.days {
            let day: Day
            if let existing = daysByID[incoming.id] {
                day = existing
                summary.daysUpdated += 1
            } else {
                day = Day(
                    id: incoming.id,
                    date: incoming.date,
                    timeZoneIdentifier: incoming.timeZoneIdentifier,
                    startedAt: incoming.startedAt
                )
                context.insert(day)
                daysByID[incoming.id] = day
                summary.daysAdded += 1
            }
            day.endedAt = incoming.endedAt
            day.endedAutomatically = incoming.endedAutomatically

            var existingSlotIDs = Set(day.slots.map(\.id))
            for incomingSlot in incoming.slots where !existingSlotIDs.contains(incomingSlot.id) {
                let slot = Slot(
                    id: incomingSlot.id,
                    startAt: incomingSlot.startAt,
                    endAt: incomingSlot.endAt,
                    state: SlotState(rawValue: incomingSlot.state) ?? .pending,
                    source: EntrySource(rawValue: incomingSlot.source) ?? .app
                )
                slot.text = incomingSlot.text
                slot.tagKeys = incomingSlot.tagKeys
                slot.loggedAt = incomingSlot.loggedAt
                if let categoryID = incomingSlot.categoryID {
                    slot.category = categoriesByID[categoryID]
                }
                context.insert(slot)
                slot.day = day
                existingSlotIDs.insert(incomingSlot.id)
                summary.slotsAdded += 1
            }
        }

        try context.save()
        return summary
    }

    // MARK: - The weekly backup

    public func rememberBackupFolder(_ url: URL) throws {
        // A folder handed over by the document picker arrives security-scoped, and the scope
        // has to be open to mint a bookmark from it — otherwise this throws and the folder
        // never gets remembered.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        settings.backupFolderBookmark = bookmark
    }

    public func forgetBackupFolder() {
        settings.backupFolderBookmark = nil
    }

    public var hasBackupFolder: Bool {
        settings.backupFolderBookmark != nil
    }

    public var isBackupDue: Bool {
        guard hasBackupFolder else { return false }
        guard let last = settings.lastBackupAt else { return true }
        return Date.now.timeIntervalSince(last) >= 7 * 24 * 3600
    }

    /// Runs the weekly backup if it is due. Silent by design — a backup you have to remember
    /// to take is not a backup.
    @discardableResult
    public func runWeeklyBackupIfDue(now: Date = .now) -> Bool {
        guard isBackupDue else { return false }
        do {
            try writeBackup(now: now)
            settings.lastBackupAt = now
            return true
        } catch {
            return false
        }
    }

    public func writeBackup(now: Date = .now) throws {
        guard let bookmark = settings.backupFolderBookmark else { throw BackupError.noFolderChosen }

        var isStale = false
        let folder = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            // Re-mint the bookmark rather than nagging: the folder is still reachable.
            settings.backupFolderBookmark = try? folder.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        guard folder.startAccessingSecurityScopedResource() else {
            throw BackupError.couldNotAccessFolder
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let data = try exportData(now: now)
        let target = folder.appendingPathComponent(fileName(for: now))
        try data.write(to: target, options: .atomic)

        pruneOldBackups(in: folder)
    }

    private func pruneOldBackups(in folder: URL) {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )) ?? []
        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix("wuut-backup-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard backups.count > retainedBackupCount else { return }
        for url in backups.dropFirst(retainedBackupCount) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Date-first so a lexicographic sort is also chronological.
    private func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "wuut-backup-\(formatter.string(from: date)).json"
    }
}
