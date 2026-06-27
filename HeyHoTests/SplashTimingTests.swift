import Testing
import Foundation

/// SplashTiming（起動スプラッシュの尺・spring パラメータ）のテスト
struct SplashTimingTests {
    private let t = SplashTiming.standard

    @Test func 静止は約1秒() {
        #expect(t.holdDuration == 1.0)
    }

    @Test func 合計はポップ静止フェードアウトの和() {
        #expect(t.totalDuration == t.popInSettle + t.holdDuration + t.fadeOutDuration)
        // 最低でも静止1秒を超える長さがあること
        #expect(t.totalDuration > 1.0)
    }

    @Test func 各フェーズ尺は正の値() {
        #expect(t.fadeInDuration > 0)
        #expect(t.popInSettle > 0)
        #expect(t.holdDuration > 0)
        #expect(t.fadeOutDuration > 0)
    }

    @Test func springはオーバーシュート条件を満たす() {
        #expect(t.springResponse > 0)
        // dampingFraction < 1 がオーバーシュート（ポップ）の条件
        #expect(t.springDamping > 0 && t.springDamping < 1)
        // 初期スケール < 1 で小さく出て弾む
        #expect(t.initialScale > 0 && t.initialScale < 1)
    }

    @Test func 残りポップ時間は負にならずクランプされる() {
        // 経過がポップ時間を超えたら 0
        #expect(t.remainingPopIn(elapsed: t.popInSettle + 0.5) == 0)
        // 未経過なら全尺
        #expect(t.remainingPopIn(elapsed: 0) == t.popInSettle)
        // 途中なら残り
        #expect(t.remainingPopIn(elapsed: t.popInSettle / 2) == t.popInSettle / 2)
    }
}
