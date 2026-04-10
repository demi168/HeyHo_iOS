import SwiftUI

/// グラデーションプリセット定義
struct GradientPreset: Identifiable, Equatable {
    let id: String
    let name: String        // 日本語表示名
    let hexStops: [String]  // 2〜3色の hex
}

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
    static let premiumGradientPresets: [GradientPreset] = [
        GradientPreset(id: "sunset",   name: "サンセット",   hexStops: ["FF6B6B", "FFD93D"]),
        GradientPreset(id: "aurora",   name: "オーロラ",     hexStops: ["6155F5", "34C759", "00C0E8"]),
        GradientPreset(id: "flamingo", name: "フラミンゴ",   hexStops: ["FF2D55", "AF52DE"]),
        GradientPreset(id: "forest",   name: "フォレスト",   hexStops: ["34C759", "FFD700"]),
        GradientPreset(id: "neon",     name: "ネオン",       hexStops: ["CB30E0", "0088FF", "00C0E8"]),
    ]
}
