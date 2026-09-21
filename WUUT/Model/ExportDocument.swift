import Foundation

/// The on-disk export format.
///
/// Versioned from the first release because this file is the only thing standing between you
/// and a total loss: on a free Apple ID the app stops launching every 7 days, and if the
/// signing identity changes or the app gets deleted the store goes with it. See SPEC §8.
///
/// It is also the eventual bridge to a Mac app, which reads the same folder.
public struct ExportDocument: Codable {

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var categories: [ExportCategory]
    public var tags: [ExportTag]
    public var days: [ExportDay]

    public init(
        schemaVersion: Int = ExportDocument.currentSchemaVersion,
        exportedAt: Date,
        categories: [ExportCategory],
        tags: [ExportTag],
        days: [ExportDay]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.categories = categories
        self.tags = tags
        self.days = days
    }
}

public struct ExportCategory: Codable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var colorHexDark: String?
    public var symbolName: String
    public var sortOrder: Int
    public var isArchived: Bool
}

public struct ExportTag: Codable {
    public var id: UUID
    public var key: String
    public var displayName: String
    public var useCount: Int
    public var lastUsedAt: Date
}

public struct ExportDay: Codable {
    public var id: UUID
    public var date: Date
    public var timeZoneIdentifier: String
    public var startedAt: Date?
    public var endedAt: Date?
    public var endedAutomatically: Bool
    public var slots: [ExportSlot]
}

public struct ExportSlot: Codable {
    public var id: UUID
    public var startAt: Date
    public var endAt: Date
    public var text: String?
    public var categoryID: UUID?
    public var tagKeys: [String]
    public var state: String
    public var source: String
    public var loggedAt: Date?
}
