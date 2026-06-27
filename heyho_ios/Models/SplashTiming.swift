import Foundation

/// 起動スプラッシュのアニメーション尺・spring パラメータを一元管理する純粋構造体。
/// View（`SplashView`）から切り出し、`HeyHoTests` でテスト可能にする（Foundation のみ依存）。
/// 数値は `CGFloat` ではなく `Double` で持ち、テスト対象の純粋性を保つ。
struct SplashTiming {
    /// ポップインの spring 応答速度（`HeyBoyLaunchOverlay` と同値）
    let springResponse: Double
    /// ポップインの spring 減衰（< 1 でオーバーシュート＝ポップ感）
    let springDamping: Double
    /// ポップ開始時のロゴスケール（< 1 で小さく出て弾む）
    let initialScale: Double

    /// ロゴのフェードイン時間（ポップと並行）
    let fadeInDuration: TimeInterval
    /// ポップの spring が視覚的に落ち着くまでの目安（reveal を急がせない保険）
    let popInSettle: TimeInterval
    /// 登場後の静止時間（約1秒）
    let holdDuration: TimeInterval
    /// フェードアウト時間
    let fadeOutDuration: TimeInterval

    /// ブランド標準値
    static let standard = SplashTiming(
        springResponse: 0.45,
        springDamping: 0.55,
        initialScale: 0.9,
        fadeInDuration: 0.30,
        popInSettle: 0.60,
        holdDuration: 1.00,
        fadeOutDuration: 0.35
    )

    /// 最短表示時間（ポップ完了 → 静止 → フェードアウト）。fadeIn は popInSettle に内包される
    var totalDuration: TimeInterval {
        popInSettle + holdDuration + fadeOutDuration
    }

    /// 経過時間からポップ完了までの残り待機を返す（負にしない）。
    /// ローディングが早く終わってもポップを見せきるための計算（`HeyBoyLaunchOverlay` と同思想）。
    func remainingPopIn(elapsed: TimeInterval) -> TimeInterval {
        max(0, popInSettle - elapsed)
    }
}
