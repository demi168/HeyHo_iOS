import LinkPresentation
import UIKit

// MARK: - 定数

enum ShareConstants {
    // TODO: リリース時に実際のApp Store IDに差し替え
    static let appStoreURL = URL(string: "https://apps.apple.com/app/heyho/id0000000000")!

    static let shareTitle = "HeyHoに招待されました"

    static func shareMessage(code: String) -> String {
        """
        HeyHoで友だちになろう！
        招待コード: \(code)

        アプリをダウンロード:
        \(appStoreURL.absoluteString)
        """
    }

    static func shareSubtitle(code: String) -> String {
        "招待コード: \(code)"
    }
}

// MARK: - UIActivityItemSource

final class InviteCodeShareItem: NSObject, UIActivityItemSource {
    private let code: String
    private let message: String

    init(code: String) {
        self.code = code
        self.message = ShareConstants.shareMessage(code: code)
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        return message
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        return message
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return ShareConstants.shareTitle
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = ShareConstants.shareTitle
        metadata.originalURL = ShareConstants.appStoreURL
        metadata.url = ShareConstants.appStoreURL

        // アプリアイコンをプレビュー画像として使用
        if let image = UIImage(named: "AppLogo") {
            let provider = NSItemProvider(object: image)
            metadata.iconProvider = provider
            metadata.imageProvider = provider
        }

        return metadata
    }
}

// MARK: - シェアサービス

enum ShareService {
    /// 招待コードのシェアシートを表示する
    static func shareInviteCode(_ code: String) {
        let shareItem = InviteCodeShareItem(code: code)
        let activityVC = UIActivityViewController(
            activityItems: [shareItem],
            applicationActivities: nil
        )

        // シェアシートから不要なアクティビティを除外
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .print,
            .saveToCameraRoll,
        ]

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else {
            return
        }

        // シートやモーダル表示中でも最前面のVCからpresentする
        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad対応
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }
}
