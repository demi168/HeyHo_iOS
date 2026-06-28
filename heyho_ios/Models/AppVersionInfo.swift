import Foundation

/// アプリのバージョン・ビルド情報の表示文字列を組み立てる純粋ロジック。
/// View に直書きせず、Bundle から読んだ値をここで整形する（テスト可能にするため）。
enum AppVersionInfo {
    /// 例: "HeyHo v1.0(77)" 形式の表示文字列を組み立てる
    static func displayString(appName: String, shortVersion: String, build: String) -> String {
        "\(appName) v\(shortVersion)(\(build))"
    }

    /// Bundle から読み出した実値で表示文字列を返す。
    /// 値が欠落していてもクラッシュせず "—" で埋める。
    static func current(bundle: Bundle = .main) -> String {
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "HeyHo"
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return displayString(appName: appName, shortVersion: shortVersion, build: build)
    }
}
