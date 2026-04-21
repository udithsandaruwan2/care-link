import SwiftUI

@main
struct care_linkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()
    @AppStorage("carelink.darkModeEnabled") private var darkModeEnabled = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(darkModeEnabled ? .dark : nil)
        }
    }
}
