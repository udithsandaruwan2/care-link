import SwiftUI

@main
struct care_linkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
