import Foundation

// MARK: - アプリ外部URL

// 招待コードのテキストシェア（ShareService / ShareConstants / InviteCodeShareItem）は
// MY PAGE の SHARE 動線が QR カードシート（InviteQRCodeView）に一本化されたため廃止した。
// AppURL は SettingsSectionView / InviteQRCodeView で使用するため保持する。

enum AppURL {
    /// Firebase Hosting のベースURL
    private static let hostingBase = "https://heyhoapp-d02f4.web.app"

    static let privacy = URL(string: "\(hostingBase)/privacy.html")!
    static let terms = URL(string: "\(hostingBase)/terms.html")!
    // 特定商取引法に基づく表記（commercial.html）は、課金機能リリース時に MyPage の導線とともに復活させる

    static let appStore = URL(string: "https://apps.apple.com/app/heyho/id6785144750")!
}
