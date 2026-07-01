import SwiftUI

enum AppColor {

    /// hex文字列から Color を生成（内部用・確定値のみ使用）。
    /// 渡すのは常にハードコードされた正しい hex なので通常フォールバックは発生しないが、
    /// 万一タイポした場合にクラッシュさせず、目立つマゼンタで気付けるようにする
    private static func hex(_ value: String) -> Color {
        Color(hex: value) ?? Color(red: 1, green: 0, blue: 1)
    }

    // MARK: - 背景
    static let backgroundPrimary   = hex("34C759")
    static let backgroundSecondary = hex("FFFFFF")
    static let backgroundSignIn    = hex("FF2D55")

    // MARK: - ボーダー
    /// Disabled 状態の枠線（Figma Grays/Gray 5）。FriendRow の返信待ち等で使用
    static let borderDisabled = hex("E5E5EA")
    static let borderStrong  = hex("000000")
    static let borderDestructive = hex("FF383C")

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
    /// 主要 CTA（ADD FRIENDS / SUBMIT 等）の黒背景
    static let buttonPrimaryBackground = hex("000000")

    // MARK: - 起動スプラッシュ
    /// 起動スプラッシュ／Launch Screen の黒背景（design-tokens gray.1000 = #000000）。
    /// Launch Screen 側は Info.plist が ColorSet "LaunchBackground"(#000000) を参照する（enum を参照できないため）。両者は同値に保つこと。
    static let splashBackground = hex("000000")

    // MARK: - オーバーレイ・シャドウ
    static let overlayScrim = Color.black.opacity(0.4)
    static let shadowSoft   = Color.black.opacity(0.1)

    // MARK: - 選択状態・装飾
    /// カラー選択中を示すリング
    static let selectionRing = Color.gray.opacity(0.5)
    /// カラーサークル上に重ねるアイコン（ロック・ダイス）
    static let iconOnAccent  = Color.white.opacity(0.9)

    // MARK: - ハイライト
    /// 新規追加行の枠線グロー等、注目を引きたい箇所に使う強調色
    static let highlightGlow = interactivePrimary

    // MARK: - テキスト
    static let textPrimary     = hex("000000")
    static let textSecondary   = hex("9CA3AF")
    /// 小見出しラベル用グレー（Figma text/label）。MY NAME IS / MY CODE IS 等
    static let textLabel       = hex("767676")
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
        ("ブラウン",    "AC7F5E"),
        ("ティール",    "00C3D0"),
        ("チャコール",  "4D4946"),
        ("ライム",      "A8D62C"),
        ("ラベンダー",  "A78BFA"),
        ("ネイビー",    "27408B"),
    ]

    // MARK: - プレミアムアイコンカラー
    static let premiumIconPresets: [(name: String, hex: String)] = [
        ("ピンク",      "FF2D55"),
        ("インディゴ",  "6155F5"),
        ("クラウド","8E8E93"),
    ]

    // MARK: - プレミアムグラデーション
    /// 実体は `GradientPreset.premiumPresets`（Models/）。デザイントークンとしての公開名のみここで提供する。
    static let premiumGradientPresets: [GradientPreset] = GradientPreset.premiumPresets
}
