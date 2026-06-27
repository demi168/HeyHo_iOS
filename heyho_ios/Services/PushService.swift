import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseMessaging

/// FCM 通知ペイロードの data フィールドのキー（Cloud Function onHeyHoCreated と対応）
private enum PushKey {
    static let type = "type"
    static let fromUserId = "fromUserId"
    static let messageType = "messageType"
    static let heyhoId = "heyhoId"
    /// type の値（HeyHo メッセージ通知）
    static let typeHeyHo = "heyho"
}

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

    /// サインイン後に呼ぶ。FCM キャッシュからトークンを取得して Firestore に保存する
    func saveTokenToFirestoreIfNeeded() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                AppLogger.push.error("FCMトークンの取得に失敗: \(error.localizedDescription)")
                return
            }
            guard let token else { return }
            self?.persistToken(token)
        }
    }

    /// FCM トークンを Firestore に保存する（サインイン済みのときのみ）
    private func persistToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await FirestoreService.shared.updateFCMToken(userId: uid, token: token)
                AppLogger.push.info("FCMトークンを保存しました")
            } catch {
                AppLogger.push.error("FCMトークンの保存に失敗: \(error.localizedDescription)")
            }
        }
    }
}

extension PushService: MessagingDelegate {
    /// FCM がトークンを発行・更新したときに呼ばれる。
    /// パラメータのトークンをそのまま使い .token の再取得は行わない（APNs 競合回避）
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        persistToken(token)
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

    /// 通知タップ時。ペイロードの送信者情報を RallyService に渡して受信を再生する（B1）。
    /// コールドスタートで friends 未ロードなら RallyService 側で保留され、ロード完了時にフラッシュされる
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo[PushKey.type] as? String == PushKey.typeHeyHo,
           let fromUserId = userInfo[PushKey.fromUserId] as? String,
           let typeRaw = userInfo[PushKey.messageType] as? String,
           let messageType = MessageType(rawValue: typeRaw) {
            Task { @MainActor in
                RallyService.shared.handlePushTap(fromUserId: fromUserId, messageType: messageType)
            }
        } else {
            AppLogger.push.error("通知ペイロードの解釈に失敗（type/fromUserId/messageType 不足）")
        }
        completionHandler()
    }
}
