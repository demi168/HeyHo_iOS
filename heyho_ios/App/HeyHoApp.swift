import SwiftUI
import FirebaseCore

@main
struct HeyHoApp: App {
    init() {
        FirebaseApp.configure()
        PushService.shared.configure()
        // 課金が有効なときのみ StoreKit 監視を開始（無料リリース時は無効）
        if PremiumConfig.isEnabled {
            StoreService.shared.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
