import SafariServices
import SwiftUI

// MARK: - カプセル型ボタン

struct CapsuleButton: View {
    let title: String
    var maxWidth: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, AppSpacing.spMedium)
                .padding(.vertical, AppSpacing.spSmall)
                .overlay(
                    Capsule()
                        .stroke(AppColor.borderStrong, lineWidth: AppSize.borderUnderline)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 主要 CTA ボタン（黒塗り・フル幅）

/// EDIT PROFILE / SUBMIT 等の主要アクションに使う黒塗りカプセルボタン。
/// `isEnabled` が false のときは無効化し半透明にする。
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTypography.heading, weight: .black))
                .foregroundColor(AppColor.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.buttonHeight)
                .background(AppColor.buttonPrimaryBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - セカンダリ CTA ボタン（白地・黒枠・フル幅）

/// COPY 等のサブアクションに使う白地＋黒枠のカプセルボタン。`PrimaryButton` と対。
struct SecondaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTypography.heading, weight: .black))
                .foregroundColor(AppColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.buttonHeight)
                .background(AppColor.backgroundSecondary, in: Capsule())
                .overlay(Capsule().strokeBorder(AppColor.borderStrong, lineWidth: AppSize.borderStrong))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - シート共通ヘッダー（中央タイトル＋任意の左右ボタン）

/// ボトムシート上部のツールバー。タイトルを中央に置き、左右に任意のボタンを配置する。
/// Figma ツールバー準拠で両サイド 16pt。グラバーは `presentationDragIndicator(.visible)` 側で表示する。
struct SheetHeader<Leading: View, Trailing: View>: View {
    private let title: String
    private let leading: Leading
    private let trailing: Trailing

    init(
        title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: AppTypography.body, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, AppSpacing.spLarge)
    }
}

/// 右クローズのみのシンプルなヘッダー（ADD FRIENDS / SHARE YOUR CODE 用）
extension SheetHeader where Leading == EmptyView, Trailing == SheetCloseButton {
    init(title: String, onClose: @escaping () -> Void) {
        self.init(
            title: title,
            leading: { EmptyView() },
            trailing: { SheetCloseButton(action: onClose) }
        )
    }
}

/// シートの円形クローズ（×）ボタン。アイコン色は用途に応じて指定可。
struct SheetCloseButton: View {
    var iconColor: Color = AppColor.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: AppTypography.body, weight: .heavy))
                .foregroundColor(iconColor)
                .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                .background(AppColor.buttonIconBackground)
                .clipShape(Circle())
        }
    }
}

// MARK: - 下線付きテキスト

struct UnderlinedText<Trailing: View>: View {
    let text: String
    let font: Font
    let trailing: Trailing

    init(text: String, font: Font, @ViewBuilder trailing: () -> Trailing) {
        self.text = text
        self.font = font
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            HStack(alignment: .center) {
                Text(text)
                    .font(font)
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                trailing
            }
            Rectangle()
                .fill(AppColor.borderStrong)
                .frame(height: AppSize.borderStrong)
        }
    }
}

extension UnderlinedText where Trailing == EmptyView {
    init(text: String, font: Font) {
        self.init(text: text, font: font) { EmptyView() }
    }
}

// MARK: - アプリ内ブラウザ

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
