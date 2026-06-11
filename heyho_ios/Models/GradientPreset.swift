import Foundation

/// グラデーションプリセット定義
///
/// 型・プリセットデータともに Foundation 単独で完結させ、テストターゲットからも参照できるようにする。
/// デザイントークンとしての公開名は `AppColor.premiumGradientPresets`（本体へのエイリアス）から参照する。
struct GradientPreset: Identifiable, Equatable {
    let id: String
    let name: String        // 日本語表示名
    let hexStops: [String]  // 2〜3色の hex

    /// プレミアムグラデーションのプリセット一覧（データの一元管理先）
    static let premiumPresets: [GradientPreset] = [
        GradientPreset(id: "sunset",   name: "サンセット",   hexStops: ["FF6B6B", "FFD93D"]),
        GradientPreset(id: "aurora",   name: "オーロラ",     hexStops: ["6155F5", "34C759", "00C0E8"]),
        GradientPreset(id: "flamingo", name: "フラミンゴ",   hexStops: ["FF2D55", "AF52DE"]),
        GradientPreset(id: "forest",   name: "フォレスト",   hexStops: ["34C759", "FFD700"]),
        GradientPreset(id: "neon",     name: "ネオン",       hexStops: ["CB30E0", "0088FF", "00C0E8"]),
    ]
}
