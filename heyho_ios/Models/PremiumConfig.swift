import Foundation

/// プレミアム機能のゲート設定を一元管理
enum PremiumConfig {
    /// StoreKit プロダクトID
    static let productId = "com.demiflare168.HeyHo.premium"

    /// 無料ユーザーが使えるアイコンカラー数（AppColor.iconPresets の先頭N個）
    static let freeColorCount = 6

    /// 無料ユーザーが使えるグラデーション数（0 = 使用不可）
    static let freeGradientCount = 0
}
