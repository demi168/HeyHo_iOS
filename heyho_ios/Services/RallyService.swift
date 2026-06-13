import Foundation
import FirebaseFirestore

/// 受信した1件のメッセージ（受信アニメ発火用）。
/// `eventId` を毎回新規にすることで「同じ種別を連続受信」しても onChange が確実に発火する。
struct IncomingHeyHo: Equatable {
    let fromUserId: String
    let messageType: MessageType
    let eventId: UUID
}

/// ラリー（Hey→Ho→LetsGo の往復）の状態とリアルタイム受信を集約するサービス。
/// - `heyhos` の `toUserId == 自分` を購読し、受信を検知して受信イベントを発火（B2）
/// - 友だちごとのラリー状態（行状態＋返信待ち）を保持（A1）
/// - プッシュタップの受信意図も集約（B1）
@MainActor
final class RallyService: ObservableObject {
    static let shared = RallyService()

    /// 友だちごとのラリー状態（行状態＋返信待ち）
    @Published private(set) var statuses: [String: FriendRallyStatus] = [:]
    /// 直近の受信イベント。View が監視して受信アニメを発火する
    @Published private(set) var incomingEvent: IncomingHeyHo?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentUserId: String?
    /// リスナー開始後の初回スナップショット（既存分の配信）を受信アニメに誤爆させないためのフラグ
    private var didReceiveInitialSnapshot = false
    /// コールドスタートでプッシュタップが先に来た場合の保留（friends ロード後にフラッシュ）
    private var pendingTap: IncomingHeyHo?

    private init() {}

    // MARK: - ライフサイクル

    /// 受信購読と行状態ロードを開始する。同一ユーザーで購読中なら friendIds 更新のみ
    func start(userId: String, friendIds: [String]) {
        if currentUserId == userId, listener != nil {
            updateFriendIds(friendIds)
            return
        }
        stop()
        currentUserId = userId
        Task { await loadStatuses(userId: userId, friendIds: friendIds) }
        subscribe(userId: userId)
        flushPendingTapIfPossible()
    }

    /// friends 再ロード時に行状態を取り直す（リスナー自体は toUserId==自分 固定なので張り替え不要）
    func updateFriendIds(_ ids: [String]) {
        guard let uid = currentUserId else { return }
        Task { await loadStatuses(userId: uid, friendIds: ids) }
        flushPendingTapIfPossible()
    }

    /// サインアウト/アカウント削除時に購読を解除して全状態をリセットする
    func stop() {
        listener?.remove()
        listener = nil
        currentUserId = nil
        statuses = [:]
        incomingEvent = nil
        didReceiveInitialSnapshot = false
        pendingTap = nil
    }

    // MARK: - 行状態

    private func loadStatuses(userId: String, friendIds: [String]) async {
        statuses = await FirestoreService.shared.getFriendRallyStatuses(userId: userId, friendIds: friendIds)
    }

    /// 送信成功時の楽観更新（相手の返信待ち = ボタン無効化）。
    /// letsGo はラリー1巡完了なので待ちにせず、次の hey を送れる状態に戻す
    func markSent(friendId: String, messageType: MessageType) {
        statuses[friendId] = FriendRallyStatus(rowState: .sendHey, awaitingReply: messageType != .letsGo)
    }

    // MARK: - 受信リスナー（B2）

    private func subscribe(userId: String) {
        didReceiveInitialSnapshot = false
        listener = db.collection("heyhos")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.handleSnapshot(snapshot, error: error)
                }
            }
    }

    private func handleSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            AppLogger.rally.error("受信リスナーのエラー: \(error.localizedDescription)")
            return
        }
        guard let snapshot else { return }
        // 初回スナップショットは既存分の配信。消化のみで受信アニメは発火しない
        guard didReceiveInitialSnapshot else {
            didReceiveInitialSnapshot = true
            return
        }
        for change in snapshot.documentChanges where change.type == .added {
            // 自分のローカル書き込みエコーは無視（防御的）
            guard !change.document.metadata.hasPendingWrites else { continue }
            guard let heyho = try? change.document.data(as: HeyHo.self) else { continue }
            receive(fromUserId: heyho.fromUserId, messageType: heyho.messageType)
        }
    }

    /// 相手からの受信を反映する（リスナー・プッシュタップ共通の入口）
    private func receive(fromUserId: String, messageType: MessageType) {
        // 相手が返信してきた → 自分の返信待ちを解除し、行状態を「返信する番」に更新
        statuses[fromUserId] = FriendRallyStatus(
            rowState: FriendRowState(sending: messageType.reply),
            awaitingReply: false
        )
        incomingEvent = IncomingHeyHo(fromUserId: fromUserId, messageType: messageType, eventId: UUID())
    }

    // MARK: - プッシュタップ集約（B1）

    /// プッシュ通知タップ時に PushService から呼ばれる。
    /// friends 未ロード（コールドスタート）なら保留し、start/updateFriendIds 完了時にフラッシュする
    func handlePushTap(fromUserId: String, messageType: MessageType) {
        if currentUserId != nil {
            receive(fromUserId: fromUserId, messageType: messageType)
        } else {
            pendingTap = IncomingHeyHo(fromUserId: fromUserId, messageType: messageType, eventId: UUID())
        }
    }

    private func flushPendingTapIfPossible() {
        guard let tap = pendingTap, currentUserId != nil else { return }
        pendingTap = nil
        receive(fromUserId: tap.fromUserId, messageType: tap.messageType)
    }

    #if DEBUG
    /// DEBUG: ダミー友だちの返信をローカルで擬似発火する（実 Firestore に乗らないため）。
    /// 実友だちの受信はリスナー/プッシュ経由なのでこのメソッドは使わない
    func debugSimulateReceive(fromUserId: String, messageType: MessageType) {
        receive(fromUserId: fromUserId, messageType: messageType)
    }
    #endif
}
