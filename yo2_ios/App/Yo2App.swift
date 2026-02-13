import SwiftUI
import FirebaseCore

@main
struct Yo2App: App {
    init() {
        FirebaseApp.configure()
        PushService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
