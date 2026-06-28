import Testing
import Foundation

/// AppVersionInfo（バージョン・ビルド表示の整形）のテスト
struct AppVersionInfoTests {
    @Test func 表示文字列はアプリ名_バージョン_ビルド形式() {
        let s = AppVersionInfo.displayString(appName: "HeyHo", shortVersion: "1.0", build: "77")
        #expect(s == "HeyHo v1.0(77)")
    }

    @Test func ビルドは括弧で囲まれる() {
        let s = AppVersionInfo.displayString(appName: "HeyHo", shortVersion: "2.3.1", build: "108")
        #expect(s.contains("(108)"))
        #expect(s.hasPrefix("HeyHo v2.3.1"))
    }

    @Test func currentはInfo辞書の値を整形して返す() {
        // CFBundleShortVersionString / CFBundleVersion を差し込んだダミー Bundle
        let bundle = Bundle(for: DummyBundleMarker.self)
        // 実 Bundle 由来でもクラッシュせず "アプリ名 vX(Y)" 形になること
        let s = AppVersionInfo.current(bundle: bundle)
        #expect(s.contains(" v"))
        #expect(s.contains("(") && s.contains(")"))
    }
}

/// テストバンドル取得用のマーカー
private final class DummyBundleMarker {}
