import Foundation

/// 友だち1人ぶんのラリー状態。
/// - `rowState`: 次に送れるメッセージ種別（行の見た目に使う）
/// - `awaitingReply`: 自分が最後に送って相手の返信を待っている状態。送信ボタンを無効化する対象
struct FriendRallyStatus: Equatable {
    var rowState: FriendRowState
    var awaitingReply: Bool
    /// 相手が最後に送ってきて自分がまだ返信していないメッセージ種別（未返信バッジ用、Issue #49）。
    /// hey / ho のときだけ設定する。letsGo は hey→ho→letsGo のラリー1巡が完了した合図で、
    /// 相手はこちらの返信を待っていない（＝未返信扱いする必要が無い）ため対象外。
    /// 自分が最後に送った/メッセージが無い場合も nil
    var incomingMessage: MessageType?

    /// 未送受信（メッセージが1件も無い）時のデフォルト
    static let initial = FriendRallyStatus(rowState: .sendHey, awaitingReply: false, incomingMessage: nil)

    /// 2人の間の最後のメッセージ情報からラリー状態を導出する。
    /// 判定本体はここ（テスト対象）に置き、Firestore 取得は FirestoreService 側が担う。
    /// リアルタイム受信（RallyService.receive）と再起動復元（FirestoreService.getFriendRallyStatuses）の
    /// 両経路がここを通るため、incomingMessage（未返信バッジ判定）もこの1箇所に一本化される。
    /// - Parameters:
    ///   - lastFromUserId: 最後のメッセージの送信者 ID（メッセージが無ければ nil）
    ///   - lastMessageType: 最後のメッセージ種別（メッセージが無ければ nil）
    ///   - me: 自分の userId
    static func from(lastFromUserId: String?, lastMessageType: MessageType?, me: String) -> FriendRallyStatus {
        guard let from = lastFromUserId, let type = lastMessageType else {
            return .initial
        }
        if from == me {
            // 自分が最後に送った。letsGo は hey→ho→letsGo のラリーが1巡完了なので
            // 返信待ちにせず、次の hey を送れる状態に戻す
            let awaitingReply = (type != .letsGo)
            return FriendRallyStatus(rowState: .sendHey, awaitingReply: awaitingReply, incomingMessage: nil)
        }
        // 相手が最後に送った = 相手のメッセージに返信する番。
        // 未返信バッジは hey/ho のみ対象（letsGo はラリー完了で返信義務が無いため incomingMessage は nil）
        let incomingMessage: MessageType? = (type == .letsGo) ? nil : type
        return FriendRallyStatus(rowState: FriendRowState(sending: type.reply), awaitingReply: false, incomingMessage: incomingMessage)
    }
}
