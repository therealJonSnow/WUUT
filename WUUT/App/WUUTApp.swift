import SwiftUI
import SwiftData

@main
struct WUUTApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container.dayController)
                .environment(container.router)
        }
        .modelContainer(container.modelContainer)
    }
}
