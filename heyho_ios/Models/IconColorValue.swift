import Foundation

/// アイコンカラーの値（ソリッドカラーまたはグラデーションプリセット）
///
/// Firestore の `iconColor` フィールドに保存する文字列と相互変換する。
/// - ソリッド: `"FF6B6B"`（既存の hex 文字列そのまま）
/// - グラデーション: `"gradient:sunset"`（プリセットIDをプレフィックス付き）
enum IconColorValue: Equatable {
    case solid(hex: String)
    case gradient(presetId: String)

    private static let gradientPrefix = "gradient:"
    private static let defaultHex = "FFD700"

    /// Firestore 文字列からパース（nil → デフォルト黄色）
    init(firestoreString: String?) {
        guard let str = firestoreString, !str.isEmpty else {
            self = .solid(hex: Self.defaultHex)
            return
        }
        if str.hasPrefix(Self.gradientPrefix) {
            let id = String(str.dropFirst(Self.gradientPrefix.count))
            self = .gradient(presetId: id)
        } else {
            self = .solid(hex: str)
        }
    }

    /// Firestore 保存用文字列
    var firestoreString: String {
        switch self {
        case .solid(let hex):
            return hex
        case .gradient(let id):
            return "\(Self.gradientPrefix)\(id)"
        }
    }
}
