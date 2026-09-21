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

    @State private var exportURL: URL?
    @State private var showFolderPicker = false
    @State private var showImportPicker = false
    @State private var message: String?
    @State private var isError = false

    private var backup: BackupService { AppContainer.shared.backup }
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        Form {
            Section {
                if settings.backupFolderBookmark == nil {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Choose a backup folder", systemImage: "folder.badge.plus")
                    }
                } else {
                    LabeledContent("Folder") {
                        Text("Chosen").foregroundStyle(.secondary)
                    }
                    LabeledContent("Last backup") {
                        Text(lastBackupLabel).foregroundStyle(.secondary)
                    }
                    Button("Back up now") { backUpNow() }
                    Button("Choose a different folder") { showFolderPicker = true }
                    Button("Stop backing up", role: .destructive) {
                        backup.forgetBackupFolder()
                    }
                }
            } header: {
                Text("Automatic weekly backup")
            } footer: {
                Text("""
                    Pick a folder in iCloud Drive and WUUT writes a dated JSON file into it once \
                    a week, keeping the last eight. It needs a folder you choose rather than \
                    iCloud sync, because iCloud sync requires a paid developer account.
                    """)
            }

            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("Prepare an export", systemImage: "square.and.arrow.up")
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share \(exportURL.lastPathComponent)", systemImage: "paperplane")
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("A versioned JSON file containing every day, slot, category and tag.")
            }

            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import a backup", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Merges by identifier, so importing a backup never overwrites or duplicates what you already have.")
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { lastBackupAt = settings.lastBackupAt }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    try backup.rememberBackupFolder(url)
                    try backup.writeBackup()
                    settings.lastBackupAt = .now
                    lastBackupAt = settings.lastBackupAt
                    report("Backed up to the folder you chose.", isError: false)
                } catch {
                    report(error.localizedDescription, isError: true)
                }
            case .failure(let error):
                report(error.localizedDescription, isError: true)
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                importBackup(from: url)
            case .failure(let error):
                report(error.localizedDescription, isError: true)
            }
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
