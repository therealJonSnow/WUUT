import SwiftUI
import UniformTypeIdentifiers

/// Backup, export and import.
///
/// This screen matters more than it looks. On a free Apple ID the app stops launching every
/// seven days, and if the signing identity changes or the app gets deleted the database goes
/// with it. The weekly backup is what makes that survivable — so set the folder once and then
/// never think about it again. See SPEC §8.
struct BackupSettingsView: View {

    /// Mirrored into view state rather than read through `@AppStorage`: the value is stored
    /// as a `Date`, and `@AppStorage` would quietly hand back a default forever.
    @State private var lastBackupAt: Date?

    /// Whether a backup folder is set. Mirrored into view state because `AppSettings` is a
    /// plain UserDefaults wrapper with no observation — reading it directly would leave this
    /// screen showing stale buttons after you choose a folder.
    @State private var hasFolder = false

    @State private var exportURL: URL?
    @State private var message: String?
    @State private var isError = false

    /// Which file the picker is being opened for.
    ///
    /// One `fileImporter` rather than two, because SwiftUI honours only a single presentation
    /// modifier of a given kind per view: stacking a folder importer and a JSON importer on
    /// the same `Form` left the folder button doing nothing at all, silently.
    private enum PickerMode {
        case backupFolder
        case importFile

        var contentTypes: [UTType] {
            switch self {
            case .backupFolder: return [.folder]
            case .importFile: return [.json]
            }
        }
    }

    @State private var pickerMode: PickerMode = .backupFolder
    @State private var isPickerPresented = false

    private var backup: BackupService { AppContainer.shared.backup }
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        Form {
            Section {
                if !hasFolder {
                    Button {
                        present(.backupFolder)
                    } label: {
                        Text("Choose a backup folder")
                            .font(Theme.serif(15, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    LabeledContent {
                        Text("Chosen").font(Theme.mono(12)).foregroundStyle(Theme.ink2)
                    } label: {
                        Marginalia("Folder", color: Theme.ink2)
                    }
                    LabeledContent {
                        Text(lastBackupLabel).font(Theme.mono(12)).foregroundStyle(Theme.ink2)
                    } label: {
                        Marginalia("Last backup", color: Theme.ink2)
                    }
                    Button("Back up now") { backUpNow() }
                    Button("Choose a different folder") { present(.backupFolder) }
                    Button {
                        backup.forgetBackupFolder()
                        hasFolder = false
                    } label: {
                        Text("Stop backing up")
                            .font(Theme.serif(15))
                            .foregroundStyle(Theme.violet)
                    }
                }
            } header: {
                SectionHeading("Automatic weekly backup")
            } footer: {
                SectionNote("""
                    Pick a folder in iCloud Drive and WUUT writes a dated JSON file into it once \
                    a week, keeping the last eight. It needs a folder you choose rather than \
                    iCloud sync, because iCloud sync requires a paid developer account.
                    """)
            }
            .logbookRow()

            Section {
                Button {
                    prepareExport()
                } label: {
                    Text("Prepare an export").font(Theme.serif(15)).foregroundStyle(Theme.ink)
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Text("Share \(exportURL.lastPathComponent)")
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.ink)
                    }
                }
            } header: {
                SectionHeading("Export")
            } footer: {
                SectionNote("A versioned JSON file containing every day, slot, category and tag.")
            }
            .logbookRow()

            Section {
                Button {
                    present(.importFile)
                } label: {
                    Text("Import a backup").font(Theme.serif(15)).foregroundStyle(Theme.ink)
                }
            } header: {
                SectionHeading("Import")
            } footer: {
                SectionNote("Merges by identifier, so importing a backup never overwrites or duplicates what you already have.")
            }

            if let message {
                Section {
                    Text(message)
                        .font(Theme.serif(13))
                        .foregroundStyle(isError ? Theme.violet : Theme.ink2)
                }
                .logbookRow()
            }
        }
        .logbookSurface()
        .logbookBars("Backup")
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: pickerMode.contentTypes
        ) { result in
            switch result {
            case .success(let url):
                switch pickerMode {
                case .backupFolder: chooseFolder(url)
                case .importFile: importBackup(from: url)
                }
            case .failure(let error):
                report(error.localizedDescription, isError: true)
            }
        }
        .onAppear {
            hasFolder = backup.hasBackupFolder
            lastBackupAt = settings.lastBackupAt
        }
    }

    private func present(_ mode: PickerMode) {
        pickerMode = mode
        isPickerPresented = true
    }

    private func chooseFolder(_ url: URL) {
        do {
            try backup.rememberBackupFolder(url)
            try backup.writeBackup()
            settings.lastBackupAt = .now
            hasFolder = true
            lastBackupAt = settings.lastBackupAt
            report("Backed up to the folder you chose.", isError: false)
        } catch {
            // Don't leave a bookmark behind that we've just proved we can't write through.
            backup.forgetBackupFolder()
            hasFolder = false
            report(error.localizedDescription, isError: true)
        }
    }

    private var lastBackupLabel: String {
        guard let date = lastBackupAt else { return "Never" }
        return "\(Formatters.longDate(date)) at \(Formatters.time(date))"
    }

    private func prepareExport() {
        do {
            exportURL = try backup.exportToTemporaryFile()
            report(nil, isError: false)
        } catch {
            report(error.localizedDescription, isError: true)
        }
    }

    private func backUpNow() {
        do {
            try backup.writeBackup()
            settings.lastBackupAt = .now
            lastBackupAt = settings.lastBackupAt
            report("Backed up.", isError: false)
        } catch {
            report(error.localizedDescription, isError: true)
        }
    }

    private func importBackup(from url: URL) {
        // A file handed over by the document picker arrives security-scoped.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let summary = try backup.importData(data)
            report(
                "Imported \(summary.daysAdded) new days, \(summary.slotsAdded) entries.",
                isError: false
            )
        } catch {
            report(error.localizedDescription, isError: true)
        }
    }

    private func report(_ text: String?, isError: Bool) {
        message = text
        self.isError = isError
    }
}
