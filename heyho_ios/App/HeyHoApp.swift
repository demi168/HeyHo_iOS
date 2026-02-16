import SwiftUI
import FirebaseCore

@main
struct HeyHoApp: App {
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
