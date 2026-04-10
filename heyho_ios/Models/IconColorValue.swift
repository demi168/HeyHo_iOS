import Foundation

/// アイコンカラーの値（ソリッドカラー / グラデーションプリセット / カスタムグラデーション）
///
/// Firestore の `iconColor` フィールドに保存する文字列と相互変換する。
/// - ソリッド: `"FF6B6B"`（既存の hex 文字列そのまま）
/// - グラデーションプリセット: `"gradient:sunset"`（プリセットIDをプレフィックス付き）
/// - カスタムグラデーション: `"gradient_custom:FF6B6B,34C759,0088FF"`（カンマ区切りhex）
enum IconColorValue: Equatable {
    case solid(hex: String)
    case gradient(presetId: String)
    case customGradient(hexStops: [String])

    private static let gradientPrefix = "gradient:"
    private static let customGradientPrefix = "gradient_custom:"
    private static let defaultHex = "FFD700"

    /// Firestore 文字列からパース（nil → デフォルト黄色）
    init(firestoreString: String?) {
        guard let str = firestoreString, !str.isEmpty else {
            self = .solid(hex: Self.defaultHex)
            return
        }
        if str.hasPrefix(Self.customGradientPrefix) {
            let stops = String(str.dropFirst(Self.customGradientPrefix.count))
                .split(separator: ",")
                .map(String.init)
            self = .customGradient(hexStops: stops)
        } else if str.hasPrefix(Self.gradientPrefix) {
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
        case .customGradient(let hexStops):
            return "\(Self.customGradientPrefix)\(hexStops.joined(separator: ","))"
        }
    }

    /// GradientPreset に変換（AnimatedGradientFill で使用）
    var gradientPreset: GradientPreset? {
        switch self {
        case .solid:
            return nil
        case .gradient(let presetId):
            return AppColor.premiumGradientPresets.first { $0.id == presetId }
        case .customGradient(let hexStops):
            return GradientPreset(id: "custom", name: "カスタム", hexStops: hexStops)
        }
    }
}
