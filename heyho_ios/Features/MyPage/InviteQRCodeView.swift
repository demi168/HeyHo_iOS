import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - QRコード表示シート（招待コードのシェアカード）

struct InviteQRCodeView: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var cardImage: UIImage?

    var body: some View {
        VStack(spacing: AppSpacing.spLarge) {
            // 閉じるボタン
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: AppTypography.body, weight: .bold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                        .background(AppColor.buttonIconBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.spLarge)

            Spacer()

            // 4:5 シェアカード
            shareCardContent
                .onAppear { renderCardImage() }

            Spacer()

            // シェアボタン
            Button(action: { shareCard() }) {
                Text("SHARE")
                    .font(.system(size: AppTypography.body, weight: .bold))
                    .foregroundColor(AppColor.iconInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.spLarge)
                    .background(AppColor.interactivePrimary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.spXlarge)
        }
        .padding(.vertical, AppSpacing.spLarge)
    }

    /// 4:5カードのコンテンツ
    private var shareCardContent: some View {
        VStack(spacing: AppSpacing.spXlarge) {
            Spacer()

            // QRコード
            if let qrImage = generateQRCode() {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
            }

            // 招待コード
            VStack(spacing: AppSpacing.spXsmall) {
                Text("MY CODE IS")
                    .font(.system(size: AppTypography.label, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                Text(inviteCode)
                    .font(.system(size: AppTypography.title, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }

            Spacer()

            // アプリロゴ
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
        }
        .padding(AppSpacing.spXlarge)
        .frame(width: 300, height: 375) // 4:5
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.spLarge))
        .shadow(color: AppColor.shadowSoft, radius: 8, y: 4)
    }

    /// カードをUIImageにレンダリング
    @MainActor
    private func renderCardImage() {
        let renderer = ImageRenderer(content: shareCardContent)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }

    /// カード画像をシェア
    private func shareCard() {
        renderCardImage()
        guard let image = cardImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }

        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

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

    /// 招待コード付きダウンロードリンクのQRコードを生成
    private func generateQRCode() -> UIImage? {
        let urlString = "\(AppURL.appStore.absoluteString)?code=\(inviteCode)"
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(urlString.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        // QRコードを鮮明にスケール
        let scale = 200 / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#if DEBUG
#Preview("QRコードシート") {
    InviteQRCodeView(inviteCode: "ABC12345")
}
#endif
