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
    static let commercial = URL(string: "\(hostingBase)/commercial.html")!

    // TODO: リリース時に実際のApp Store IDに差し替え
    static let appStore = URL(string: "https://apps.apple.com/app/heyho/id0000000000")!
}
