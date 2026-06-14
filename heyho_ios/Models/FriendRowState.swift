import Foundation

/// 友だちリストの1行が「Hey / Ho / Let's Go」のどれを送れるかを表す
enum FriendRowState: Equatable {
    case sendHey        // デフォルト: Heyを送る
    case sendLetsGo     // 相手からHoが返ってきた後: LetsGoを送る
    case sendHo         // 相手からHeyが来た後: Hoを返す

    /// 「次に送るべきメッセージタイプ」から行状態を決める
    init(sending type: MessageType) {
        switch type {
        case .hey: self = .sendHey
        case .ho: self = .sendHo
        case .letsGo: self = .sendLetsGo
        }
    }

    /// この行状態で送るメッセージ種別（init(sending:) の逆）
    var sendableMessage: MessageType {
        switch self {
        case .sendHey: return .hey
        case .sendHo: return .ho
        case .sendLetsGo: return .letsGo
        }
    }
}
