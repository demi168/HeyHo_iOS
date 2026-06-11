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
