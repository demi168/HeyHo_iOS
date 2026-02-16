import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseMessaging

final class PushService: NSObject {
    static let shared = PushService()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func saveTokenToFirestoreIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCMトークンの取得に失敗: \(error.localizedDescription)")
                return
            }
            guard let token = token else { return }
            Task {
                do {
                    try await FirestoreService.shared.updateFCMToken(userId: uid, token: token)
                } catch {
                    print("FCMトークンの保存に失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension PushService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        saveTokenToFirestoreIfNeeded()
    }
}

extension PushService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
