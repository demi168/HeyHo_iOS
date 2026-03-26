import SwiftUI

/// グラデーションプリセット定義
struct GradientPreset: Identifiable, Equatable {
    let id: String
    let name: String        // 日本語表示名
    let hexStops: [String]  // 2〜3色の hex
}

enum AppColor {
    // MARK: - 背景
    static let backgroundPrimary = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let backgroundSecondary = Color(red: 1.000, green: 1.000, blue: 1.000)
    static let backgroundSignIn = Color(red: 1.000, green: 0.176, blue: 0.333)

    // MARK: - ボーダー
    static let borderDefault = Color(red: 0.898, green: 0.906, blue: 0.922)
    static let borderStrong = Color(red: 0.000, green: 0.000, blue: 0.000)

    // MARK: - アイコン
    static let iconDefault = Color(red: 0.000, green: 0.000, blue: 0.000)
    static let iconInverse = Color(red: 1.000, green: 1.000, blue: 1.000)

    // MARK: - インタラクティブ
    static let interactivePrimary = Color(red: 0.000, green: 0.533, blue: 1.000)
    static let interactiveDestructive = Color(red: 1.000, green: 0.220, blue: 0.235)

    // MARK: - メッセージ
    static let messageHey = Color(red: 0.000, green: 0.533, blue: 1.000)
    static let messageHo = Color(red: 1.000, green: 0.553, blue: 0.157)
    static let messageLetsGo = Color(red: 0.204, green: 0.780, blue: 0.349)

    // MARK: - テキスト
    static let textPrimary = Color(red: 0.000, green: 0.000, blue: 0.000)
    static let textSecondary = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let textDestructive = Color(red: 1.000, green: 0.220, blue: 0.235)
    static let textInverse = Color(red: 1.000, green: 1.000, blue: 1.000)

    // MARK: - アイコンカラープリセット
    static let iconPresets: [(name: String, hex: String)] = [
        ("シアン",      "00C0E8"),
        ("ピンク",      "FF2D55"),
        ("ブラウン",    "AC7F5E"),
        ("パープル",    "CB30E0"),
        ("グリーン",    "34C759"),
        ("オレンジ",    "FF8D28"),
        ("ブルー",      "0088FF"),
        ("レッド",      "FF383C"),
        ("イエロー",    "FFCC00"),
        ("ティール",    "00C3D0"),
        ("インディゴ",  "6155F5"),
        ("バイオレット","AF52DE"),
    ]

    // MARK: - グラデーションプリセット（プレミアム専用）
    static let gradientPresets: [GradientPreset] = [
        GradientPreset(id: "sunset",   name: "サンセット",   hexStops: ["FF6B6B", "FFD93D"]),
        GradientPreset(id: "ocean",    name: "オーシャン",   hexStops: ["0088FF", "00C3D0"]),
        GradientPreset(id: "aurora",   name: "オーロラ",     hexStops: ["6155F5", "34C759", "00C0E8"]),
        GradientPreset(id: "flamingo", name: "フラミンゴ",   hexStops: ["FF2D55", "AF52DE"]),
        GradientPreset(id: "forest",   name: "フォレスト",   hexStops: ["34C759", "FFD700"]),
        GradientPreset(id: "neon",     name: "ネオン",       hexStops: ["CB30E0", "0088FF", "00C0E8"]),
    ]

    // MARK: - プレビュー用デフォルト
    static let defaultIconYellow = Color(red: 1.000, green: 0.800, blue: 0.000)
    static let defaultIconCyan = Color(red: 0.000, green: 0.753, blue: 0.910)
}
