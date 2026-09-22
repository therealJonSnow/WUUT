import SwiftUI

struct RootView: View {

    @Environment(DayController.self) private var dayController
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasBootstrapped = false
    @State private var notificationsDenied = false

    var body: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        )) {
            TodayView()
                .tabItem { Label("Today", systemImage: "list.bullet.rectangle") }
                .tag(AppRouter.Tab.today)

            WeekView()
                .tabItem { Label("Week", systemImage: "chart.bar.fill") }
                .tag(AppRouter.Tab.week)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .overlay(alignment: .top) {
            if let message = AppContainer.shared.storeFailureMessage {
                storeFailureBanner(message)
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true
            dayController.bootstrap()

            let granted = await AppContainer.shared.notifications.requestAuthorization()
            notificationsDenied = !granted

            AppContainer.shared.backup.runWeeklyBackupIfDue()
            BackgroundRefresh.schedule()
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the foreground is the most common wake, so it is the most
            // important moment to re-derive state and top up the notification window.
            if phase == .active {
                dayController.reconcile()
                AppContainer.shared.backup.runWeeklyBackupIfDue()
            }
        }
        .alert("Notifications are off", isPresented: $notificationsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("WUUT prompts you every quarter hour. Without notifications it can't do the one thing it's for.")
        }
    }

    private func storeFailureBanner(_ message: String) -> some View {
        Text(message)
            .font(Theme.serif(13))
            .foregroundStyle(Theme.card)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink)
            .transition(.move(edge: .top))
    }
}
