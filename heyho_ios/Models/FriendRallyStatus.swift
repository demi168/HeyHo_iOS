import Foundation

/// 友だち1人ぶんのラリー状態。
/// - `rowState`: 次に送れるメッセージ種別（行の見た目に使う）
/// - `awaitingReply`: 自分が最後に送って相手の返信を待っている状態。送信ボタンを無効化する対象
struct FriendRallyStatus: Equatable {
    var rowState: FriendRowState
    var awaitingReply: Bool

    /// 未送受信（メッセージが1件も無い）時のデフォルト
    static let initial = FriendRallyStatus(rowState: .sendHey, awaitingReply: false)

    /// 2人の間の最後のメッセージ情報からラリー状態を導出する。
    /// 判定本体はここ（テスト対象）に置き、Firestore 取得は FirestoreService 側が担う。
    /// - Parameters:
    ///   - lastFromUserId: 最後のメッセージの送信者 ID（メッセージが無ければ nil）
    ///   - lastMessageType: 最後のメッセージ種別（メッセージが無ければ nil）
    ///   - me: 自分の userId
    static func from(lastFromUserId: String?, lastMessageType: MessageType?, me: String) -> FriendRallyStatus {
        guard let from = lastFromUserId, let type = lastMessageType else {
            return .initial
        }
        if from == me {
            // 自分が最後に送った = 相手の返信待ち（ボタン無効化）
            return FriendRallyStatus(rowState: .sendHey, awaitingReply: true)
        }
        // 相手が最後に送った = 相手のメッセージに返信する番
        return FriendRallyStatus(rowState: FriendRowState(sending: type.reply), awaitingReply: false)
    }
}
