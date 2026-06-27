import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - シェアシート（SHARE YOUR CODE）
//
// 招待コードの QR と「シェア時点の自分のカラーの HeyBoy」を載せたカード(shareImg)を表示し、
// 画像＋テキストの共有（SHARE）/ テキストのコピー（COPY）を行う。

struct InviteQRCodeView: View {
    let inviteCode: String
    /// シェア時点の自分のアイコンカラー（カードの HeyBoy に反映）
    var iconColorValue: IconColorValue = .solid(hex: AppColor.defaultIconHex)
    @Environment(\.dismiss) private var dismiss

    /// COPY 直後にラベルを COPIED! に切り替えるフラグ
    @State private var didCopy = false
    /// COPIED! 表示を一定時間後に戻すタスク（多重タップ時はキャンセルして貼り直す）
    @State private var copyResetTask: Task<Void, Never>?

    /// シートの高さ（呼び出し側の presentationDetents と共有・1箇所管理）
    static let sheetDetentHeight: CGFloat = 700

    // カード固有のレイアウト寸法（Figma shareImg 準拠・ここ1箇所で調整）
    private enum Card {
        static let width: CGFloat = 329          // 393 - 32*2
        static let corner: CGFloat = 24          // radius/2xl
        static let topInset: CGFloat = 72        // pt-72（ロゴの下に QR を置く）
        static let qrSize: CGFloat = 220
        static let qrCorner: CGFloat = 11
        static let qrPadding: CGFloat = 12       // QR の白フチ（quiet zone）
        static let logoWidth: CGFloat = 93
        static let logoOffset = CGPoint(x: 6, y: -1)
        static let heyBoySize: CGFloat = 140     // 右下から見切れて覗く
        static let heyBoyOffset = CGSize(width: 40, height: -44)
    }

    /// 共有テキスト（英語ブランド調・末尾にコード付きDLリンク）
    private var shareText: String {
        "Let's HeyHo! My code: \(inviteCode)\n\(downloadLink)"
    }

    /// コード付きダウンロードリンク（QR と同一・#40 と整合）
    private var downloadLink: String {
        "\(AppURL.appStore.absoluteString)?code=\(inviteCode)"
    }

    var body: some View {
        VStack(spacing: AppSpacing.spLarge) {
            SheetHeader(title: "SHARE YOUR CODE", onClose: { dismiss() })

            VStack(spacing: AppSpacing.spXxlarge) {
                shareCard
                VStack(spacing: AppSpacing.spLarge) {
                    PrimaryButton(title: "SHARE") { shareCardImage() }
                    SecondaryButton(title: didCopy ? "COPIED!" : "COPY") { copyShareText() }
                }
            }
            .frame(width: Card.width)

            Spacer(minLength: 0)
        }
        .padding(.top, AppSpacing.spMedium)
        .frame(maxWidth: .infinity)
        .background(AppColor.backgroundSecondary)
    }

    // MARK: - shareImg カード（共有画像としてレンダリングする本体）

    private var shareCard: some View {
        VStack(spacing: AppSpacing.spLarge) {
            qrCodeView

            // MY CODE IS + コード（下線）
            VStack(spacing: 0) {
                Text("MY CODE IS")
                    .font(.system(size: AppTypography.label, weight: .bold))
                    .foregroundColor(AppColor.textPrimary.opacity(0.6))
                Text(inviteCode)
                    .font(.system(size: AppTypography.display, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                    // 下線をコード（8桁）の実幅に合わせるため、テキスト幅にフィットさせる
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.vertical, AppSpacing.spXsmall)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppColor.borderStrong)
                            .frame(height: AppSize.borderStrong)
                    }
            }
        }
        .padding(.top, Card.topInset)
        .padding(.horizontal, AppSpacing.spXxlarge)
        .padding(.bottom, AppSpacing.spXxlarge)
        .frame(width: Card.width)
        .background(AppColor.backgroundPrimary)
        .overlay(alignment: .topLeading) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: Card.logoWidth)
                .offset(x: Card.logoOffset.x, y: Card.logoOffset.y)
        }
        .overlay(alignment: .bottomTrailing) {
            HeyBoyIconView(
                iconColorValue: iconColorValue,
                size: Card.heyBoySize,
                animated: false,
                showBackground: false
            )
            .offset(x: Card.heyBoyOffset.width, y: Card.heyBoyOffset.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: Card.corner))
    }

    /// QR（白地・角丸・quiet zone 付き）
    private var qrCodeView: some View {
        Group {
            if let qr = generateQRCode() {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(Card.qrPadding)
            }
        }
        .frame(width: Card.qrSize, height: Card.qrSize)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Card.qrCorner))
    }

    // MARK: - アクション

    /// カードを画像化し、画像＋テキストでシステム共有シートを開く
    private func shareCardImage() {
        guard let image = renderCardImage() else { return }
        let activityVC = UIActivityViewController(
            activityItems: [image, shareText],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        var topVC = root
        while let presented = topVC.presentedViewController { topVC = presented }

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

    /// 共有テキストをクリップボードへコピーし、ラベルを一時的に COPIED! にする
    private func copyShareText() {
        UIPasteboard.general.string = shareText
        // 短いタップ感のハプティック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { didCopy = true }
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            withAnimation { didCopy = false }
        }
    }

    /// カードを UIImage にレンダリング（高解像度・ライト固定）
    @MainActor
    private func renderCardImage() -> UIImage? {
        let renderer = ImageRenderer(content: shareCard.environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// 招待コード付きダウンロードリンクの QR コードを生成
    private func generateQRCode() -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(downloadLink.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        // QR を鮮明にスケール
        let scale = 200 / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#if DEBUG
#Preview("SHARE YOUR CODE") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InviteQRCodeView(inviteCode: "ABC12345", iconColorValue: .solid(hex: "FFCC00"))
                .presentationDetents([.height(InviteQRCodeView.sheetDetentHeight)])
                .presentationDragIndicator(.visible)
        }
}
#endif
