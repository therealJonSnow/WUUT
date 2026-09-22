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
                // Light only, on purpose. Paper at night is a different design rather than
                // an inverted one, and a half-considered dark mode is worse than none.
                .preferredColorScheme(.light)
        }
        .modelContainer(container.modelContainer)
    }
}
