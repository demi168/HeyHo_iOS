import Foundation
import FirebaseFirestore

/// 受信した1件のメッセージ（受信アニメ発火用）。
/// `eventId` を毎回新規にすることで「同じ種別を連続受信」しても onChange が確実に発火する。
struct IncomingHeyHo: Equatable {
    let fromUserId: String
    let messageType: MessageType
    let eventId: UUID
}

/// 自分が「友だちに追加された側」になったことを表すイベント（新規追加演出発火用）。
/// `eventId` を毎回新規にすることで「同じ相手の再追加」でも onChange が確実に発火する。
struct FriendAddedEvent: Equatable {
    let friendId: String
    /// true = プッシュタップ起動経由、false = アプリ起動中のリスナー検知
    let isFromPushTap: Bool
    let eventId: UUID
}

/// ラリー（Hey→Ho→LetsGo の往復）の状態とリアルタイム受信を集約するサービス。
/// - `heyhos` の `toUserId == 自分` を購読し、受信を検知して受信イベントを発火（B2）
/// - 友だちごとのラリー状態（行状態＋返信待ち）を保持（A1）
/// - プッシュタップの受信意図も集約（B1）
/// - `users/{uid}/friends` を購読し、「追加された側」の検知も集約（リスナー・プッシュタップ両経路）
@MainActor
final class RallyService: ObservableObject {
    static let shared = RallyService()

    /// 友だちごとのラリー状態（行状態＋返信待ち）
    @Published private(set) var statuses: [String: FriendRallyStatus] = [:]
    /// 直近の受信イベント。View が監視して受信アニメを発火する
    @Published private(set) var incomingEvent: IncomingHeyHo?
    /// 直近の「友だちに追加された」イベント。View が監視して新規追加演出を発火する
    @Published private(set) var friendAddedEvent: FriendAddedEvent?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?
    private var currentUserId: String?
    private var loadStatusesTask: Task<Void, Never>?
    /// リスナー開始後の初回スナップショット（既存分の配信）を受信アニメに誤爆させないためのフラグ
    private var didReceiveInitialSnapshot = false
    /// friends リスナーの初回スナップショット（既存分の配信）を新規追加演出に誤爆させないためのフラグ
    private var didReceiveInitialFriendsSnapshot = false
    /// コールドスタートでプッシュタップが先に来た場合の保留（friends ロード後にフラッシュ）
    private var pendingTap: IncomingHeyHo?
    /// コールドスタートで「友だちに追加された」プッシュタップが先に来た場合の保留（friends ロード後にフラッシュ）
    private var pendingFriendAddedTap: FriendAddedEvent?
    /// friendAddedEvent を発行済みの友だちID（同一友だちに対する二重発火防止）。
    /// 例: フォアグラウンドでリスナー検知→演出済みの後、通知バナーをタップした場合など
    private var emittedFriendAddedIds: Set<String> = []

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
        loadStatusesTask = Task { await loadStatuses(userId: userId, friendIds: friendIds) }
        subscribe(userId: userId)
        subscribeFriends(userId: userId)
        flushPendingTapIfPossible()
        flushPendingFriendAddedTapIfPossible()
    }

    /// friends 再ロード時に行状態を取り直す（リスナー自体は toUserId==自分 固定なので張り替え不要）
    func updateFriendIds(_ ids: [String]) {
        guard let uid = currentUserId else { return }
        loadStatusesTask?.cancel()
        loadStatusesTask = Task { await loadStatuses(userId: uid, friendIds: ids) }
        flushPendingTapIfPossible()
        flushPendingFriendAddedTapIfPossible()
    }

    /// サインアウト/アカウント削除時に購読を解除して全状態をリセットする
    func stop() {
        loadStatusesTask?.cancel()
        loadStatusesTask = nil
        listener?.remove()
        listener = nil
        friendsListener?.remove()
        friendsListener = nil
        currentUserId = nil
        statuses = [:]
        incomingEvent = nil
        friendAddedEvent = nil
        didReceiveInitialSnapshot = false
        didReceiveInitialFriendsSnapshot = false
        pendingTap = nil
        pendingFriendAddedTap = nil
        emittedFriendAddedIds = []
    }

    // MARK: - 行状態

    private func loadStatuses(userId: String, friendIds: [String]) async {
        let result = await FirestoreService.shared.getFriendRallyStatuses(userId: userId, friendIds: friendIds)
        guard !Task.isCancelled else { return }
        statuses = result
    }

    /// 送信成功時の楽観更新（相手の返信待ち = ボタン無効化）。
    /// letsGo はラリー1巡完了なので待ちにせず、次の hey を送れる状態に戻す
    func markSent(friendId: String, messageType: MessageType) {
        // 自分から送った直後なので、相手からの未返信メッセージは無い（バッジは消える）
        statuses[friendId] = FriendRallyStatus(rowState: .sendHey, awaitingReply: messageType != .letsGo, incomingMessage: nil)
    }

    // MARK: - 受信リスナー（B2）

    private func subscribe(userId: String) {
        didReceiveInitialSnapshot = false
        listener = db.collection("heyhos")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            // 必要なのは「開始後に追加された最新の受信」だけ。全履歴を読まないよう最新1件に限定
            .limit(to: 1)
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
        // 相手が最後に送った状態としてラリー状態を導出（行状態の決め方は from に一本化）
        if let me = currentUserId {
            statuses[fromUserId] = FriendRallyStatus.from(
                lastFromUserId: fromUserId,
                lastMessageType: messageType,
                me: me
            )
        }
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

    /// ローカル友だち（チュートリアルボット・デバッグダミー）の返信を擬似発火する。
    /// 実 Firestore に乗らないため、ローカルシミュレーション専用
    func simulateLocalReceive(fromUserId: String, messageType: MessageType) {
        receive(fromUserId: fromUserId, messageType: messageType)
    }

    // MARK: - 友だち追加検知（アプリ起動中のリスナー経路）

    private func subscribeFriends(userId: String) {
        didReceiveInitialFriendsSnapshot = false
        friendsListener = db.collection("users").document(userId).collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.handleFriendsSnapshot(snapshot, error: error)
                }
            }
    }

    private func handleFriendsSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            AppLogger.rally.error("友だちリスナーのエラー: \(error.localizedDescription)")
            return
        }
        guard let snapshot else { return }
        // 初回スナップショットは既存分の配信。消化のみで新規追加演出は発火しない
        guard didReceiveInitialFriendsSnapshot else {
            didReceiveInitialFriendsSnapshot = true
            return
        }
        for change in snapshot.documentChanges {
            switch change.type {
            case .added:
                // 自分のローカル書き込みエコー（自分が追加した側）は無視（防御的）。
                // 既定のリスナー（includeMetadataChanges 未指定）では、pending write が解消された
                // だけのメタデータのみの変化は再配信されないため、自分のローカル書き込みが
                // hasPendingWrites=false のスナップショットとして再度 .added で届くことはなく、
                // 二重発火しない
                guard !change.document.metadata.hasPendingWrites else { continue }
                emitFriendAddedEvent(friendId: change.document.documentID, isFromPushTap: false)
            case .removed:
                // 削除→再追加を再度検知できるよう、発行済みIDから外す（未発行IDのremoveは無害）
                emittedFriendAddedIds.remove(change.document.documentID)
            case .modified:
                break
            }
        }
    }

    // MARK: - 友だち追加検知（プッシュタップ経路）

    /// 「◯◯さんと友だちになりました」通知タップ時に PushService から呼ばれる。
    /// friends 未ロード（コールドスタート）なら保留し、start/updateFriendIds 完了時にフラッシュする
    func handleFriendAddedPushTap(friendId: String) {
        if currentUserId != nil {
            emitFriendAddedEvent(friendId: friendId, isFromPushTap: true)
        } else {
            pendingFriendAddedTap = FriendAddedEvent(friendId: friendId, isFromPushTap: true, eventId: UUID())
        }
    }

    private func flushPendingFriendAddedTapIfPossible() {
        guard let tap = pendingFriendAddedTap, currentUserId != nil else { return }
        pendingFriendAddedTap = nil
        emitFriendAddedEvent(friendId: tap.friendId, isFromPushTap: tap.isFromPushTap)
    }

    /// friendAddedEvent 発行の共通口。同一友だちに対する重複発火をここで一元的に防ぐ
    private func emitFriendAddedEvent(friendId: String, isFromPushTap: Bool) {
        guard !emittedFriendAddedIds.contains(friendId) else { return }
        emittedFriendAddedIds.insert(friendId)
        friendAddedEvent = FriendAddedEvent(friendId: friendId, isFromPushTap: isFromPushTap, eventId: UUID())
    }
}
