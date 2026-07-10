import Foundation

/// 友だち追加イベント受信時にFriendsViewが取るべきアクション（純粋な判定ロジック）
enum FriendAddedAction: Equatable {
    /// 何もしない（追加した側のフロー等）
    case skip
    /// 既存行を先頭移動＋ハイライト（Pushタップ起動）
    case highlightExisting
    /// 取得して先頭挿入＋ハイライト
    case fetchAndInsert

    /// - Parameters:
    ///   - alreadyInList: 対象の友だちが既に一覧に存在するか
    ///   - isFromPushTap: プッシュ通知タップ起動経由か（false ならアプリ起動中のリスナー検知）
    static func decide(alreadyInList: Bool, isFromPushTap: Bool) -> FriendAddedAction {
        switch (alreadyInList, isFromPushTap) {
        case (true, false): return .skip
        case (true, true): return .highlightExisting
        case (false, _): return .fetchAndInsert
        }
    }
}
