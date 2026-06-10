import Foundation

/// プレミアム機能のゲート設定を一元管理
enum PremiumConfig {
    /// 課金動線・プレミアム機能の有効化フラグ。
    /// `false`: 無料アプリとして動作（課金UI・プレミアム色/グラデーションを完全非表示、StoreKit 無効）。
    /// 将来課金を再導入する際は `true` にするだけで関連UI・StoreKit 監視が復活する。
    /// ※ letsGo メッセージはこのフラグと無関係に常時無料（誰でも送信可）。
    static let isEnabled = false

    /// StoreKit プロダクトID
    static let productId = "com.demiflare168.HeyHo.premium"

    /// 無料ユーザーが使えるグラデーション数（0 = 使用不可）
    static let freeGradientCount = 0
}
