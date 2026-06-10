import Foundation

/// HeyHo のメッセージ種別。返信は hey → ho → letsGo → hey の順に循環する
enum MessageType: String, Codable {
    case hey
    case ho
    case letsGo

    /// このメッセージを受け取った側が次に送るべき返信タイプ
    var reply: MessageType {
        switch self {
        case .hey: return .ho
        case .ho: return .letsGo
        case .letsGo: return .hey
        }
    }
}
