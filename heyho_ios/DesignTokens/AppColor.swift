import SwiftUI

enum AppColor {

    /// hex文字列から Color を生成（内部用・確定値のみ使用）
    private static func hex(_ value: String) -> Color {
        Color(hex: value)!
    }

    // MARK: - 背景
    static let backgroundPrimary   = hex("34C759")
    static let backgroundSecondary = hex("FFFFFF")
    static let backgroundSignIn    = hex("FF2D55")

    // MARK: - ボーダー
    static let borderDefault = hex("E5E7EB")
    static let borderStrong  = hex("000000")

    // MARK: - アイコン
    static let iconDefault = hex("000000")
    static let iconInverse = hex("FFFFFF")

    // MARK: - インタラクティブ
    static let interactivePrimary     = hex("0088FF")
    static let interactiveDestructive = hex("FF383C")

    // MARK: - メッセージ
    static let messageHey    = hex("0088FF")
    static let messageHo     = hex("FF8D28")
    static let messageLetsGo = hex("34C759")

    // MARK: - ボタン背景
    static let buttonIconBackground = Color(white: 0.9)

    // MARK: - テキスト
    static let textPrimary     = hex("000000")
    static let textSecondary   = hex("9CA3AF")
    static let textTertiary   = hex("BFBFBF")
    static let textDestructive = hex("FF383C")
    static let textInverse     = hex("FFFFFF")

    // MARK: - デフォルトアイコンカラー
    static let defaultIconHex = "FFCC00"
    static let defaultIconColor = hex("FFCC00")

    // MARK: - フリーアイコンカラー
    static let freeIconPresets: [(name: String, hex: String)] = [
        ("イエロー",    "FFCC00"),
        ("ブルー",      "0088FF"),
        ("レッド",      "FF383C"),
        ("パープル",    "CB30E0"),
        ("グリーン",    "34C759"),
        ("オレンジ",    "FF8D28"),
    ]

    // MARK: - プレミアムアイコンカラー
    static let premiumIconPresets: [(name: String, hex: String)] = [
        ("ピンク",      "FF2D55"),
        ("ブラウン",    "AC7F5E"),
        ("ティール",    "00C3D0"),
        ("インディゴ",  "6155F5"),
        ("クラウド","8E8E93"),
    ]

    // MARK: - プレミアムグラデーション
    /// 実体は `GradientPreset.premiumPresets`（Models/）。デザイントークンとしての公開名のみここで提供する。
    static let premiumGradientPresets: [GradientPreset] = GradientPreset.premiumPresets
}
