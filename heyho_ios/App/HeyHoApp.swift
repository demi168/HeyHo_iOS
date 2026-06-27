import SwiftUI
import FirebaseCore
import FirebaseMessaging

// MARK: - AppDelegate

/// APNs デバイストークンを Firebase Messaging に橋渡しする。
/// SwiftUI の @main + App 構造では UIApplicationDelegate が存在しないと
/// Method Swizzling が確実に機能しないため、明示的に渡す。
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.push.error("APNs登録失敗: \(error.localizedDescription)")
    }
}

// MARK: - HeyHoApp

@main
struct HeyHoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
