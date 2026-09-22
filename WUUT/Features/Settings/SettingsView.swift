import SwiftUI
import UserNotifications

struct SettingsView: View {

    @Environment(DayController.self) private var dayController: DayController

    @AppStorage(SettingsKey.firstFollowUpMinutes) private var firstFollowUp = 5
    @AppStorage(SettingsKey.secondFollowUpMinutes) private var secondFollowUp = 11
    @AppStorage(SettingsKey.promptWindowSlotCount) private var windowSlots = 18
    @AppStorage(SettingsKey.useTimeSensitive) private var useTimeSensitive = true
    @AppStorage(SettingsKey.daySummaryEnabled) private var daySummary = true
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveActivity = true
    @AppStorage(SettingsKey.minimumStubMinutes) private var minimumStub = 3
    @AppStorage(SettingsKey.backfillWindowMinutes) private var backfillWindow = 120
    @AppStorage(SettingsKey.autoEndHour) private var autoEndHour = 2

    @State private var pendingPromptCount = 0
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                promptsSection
                daySection
                organisationSection
                dataSection
                diagnosticsSection
            }
            .logbookSurface()
            .logbookBars("Settings")
            .task { await refreshDiagnostics() }
        }
    }

    // MARK: - Prompts

    private var promptsSection: some View {
        Section {
            Stepper("First follow-up  \(firstFollowUp) min", value: $firstFollowUp, in: 1...14)
            Stepper("Second follow-up  \(secondFollowUp) min", value: $secondFollowUp, in: 2...14)
            Toggle("Break through Focus", isOn: $useTimeSensitive)
            Toggle("End-of-day summary", isOn: $daySummary)
            Toggle("Lock screen activity", isOn: $liveActivity)
        } header: {
            SectionHeading("Prompts")
        } footer: {
            SectionNote("""
                Each slot gets a prompt the moment it ends, then two follow-ups, all cancelled \
                as soon as you log it. The escalation is the point of the app — these timings \
                are a guess, so change them.

                "Break through Focus" asks for Time Sensitive delivery. It needs an entitlement \
                that may not be available on a free Apple ID; turn it off if prompts misbehave.
                """)
        }
        .logbookRow()
    }

    // MARK: - The day

    private var daySection: some View {
        Section {
            Stepper("Shortest stub  \(minimumStub) min", value: $minimumStub, in: 0...10)
            Picker("Backfill window", selection: $backfillWindow) {
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
                Text("2 hours").tag(120)
                Text("4 hours").tag(240)
            }
            Picker("Close a forgotten day at", selection: $autoEndHour) {
                ForEach([0, 1, 2, 3, 4, 5], id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
        } header: {
            SectionHeading("The day")
        } footer: {
            SectionNote("""
                Your first slot runs from the moment you start to the next quarter hour. A stub \
                shorter than the minimum is folded into the following slot instead.

                After the backfill window a slot locks as unaccounted and cannot be edited. \
                That is deliberate: a lock you can undo is not a lock.
                """)
        }
        .logbookRow()
    }

    private var organisationSection: some View {
        Section {
            NavigationLink {
                CategoryEditorView()
            } label: {
                Text("Categories").font(Theme.serif(15)).foregroundStyle(Theme.ink)
            }
        } header: {
            SectionHeading("Organisation")
        }
        .logbookRow()
    }

    private var dataSection: some View {
        Section {
            NavigationLink {
                BackupSettingsView()
            } label: {
                Text("Backup and export").font(Theme.serif(15)).foregroundStyle(Theme.ink)
            }
        } header: {
            SectionHeading("Data")
        }
        .logbookRow()
    }

    // MARK: - Diagnostics
    //
    // Visible on purpose. The rolling notification window is the one mechanism whose failure
    // would be silent — iOS drops requests past 64 without telling anyone — so its state is
    // something you can check rather than trust.

    private var diagnosticsSection: some View {
        Section {
            LabeledContent("Notifications") {
                Text(authorizationLabel)
                    .foregroundStyle(authorizationStatus == .authorized ? Theme.ink2 : Theme.violet)
            }
            LabeledContent("Prompts scheduled") {
                Text("\(pendingPromptCount) of \(NotificationScheduler.platformPendingLimit)")
                    .font(Theme.mono(13))
                    .foregroundStyle(pendingPromptCount > 60 ? Theme.violet : Theme.ink2)
            }
            LabeledContent("Window") {
                Text("\(windowSlots) slots")
                    .monospacedDigit()
            }
            Button("Re-check") {
                Task { await refreshDiagnostics() }
            }
            .font(Theme.serif(15))
            .foregroundStyle(Theme.ink)
        } header: {
            SectionHeading("Diagnostics")
        } footer: {
            SectionNote("""
                iOS keeps at most 64 pending notifications, which a full day of three prompts \
                per slot would exceed several times over. WUUT schedules a rolling window of \
                the next \(windowSlots) slots and tops it up whenever you use the app or answer \
                a prompt. If this number sits at zero during a logged day, something is wrong.
                """)
        }
    }

    private var authorizationLabel: String {
        switch authorizationStatus {
        case .authorized: return "On"
        case .provisional: return "Provisional"
        case .denied: return "Off — prompts won't arrive"
        case .notDetermined: return "Not asked yet"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func refreshDiagnostics() async {
        let scheduler = AppContainer.shared.notifications
        pendingPromptCount = await scheduler.pendingPromptCount()
        authorizationStatus = await scheduler.authorizationStatus()
    }
}
