import SwiftUI

// MARK: - 名前入力フォーム（EditProfileView 用・純粋 UI）

struct NameInputSection: View {
    @Binding var displayName: String
    let validationError: String?
    /// true の場合、表示時に入力欄へフォーカスする（初回セットアップ時）
    let focusOnAppear: Bool

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spSmall) {
            Text("MY NAME IS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)

            VStack(spacing: AppSpacing.spXsmall) {
                TextField("6-16 characters", text: $displayName,
                         prompt: Text("6-16 characters")
                            .foregroundColor(AppColor.textTertiary))
                    .font(.system(size: AppTypography.title, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                Rectangle()
                    .fill(validationError != nil ? AppColor.borderDestructive : AppColor.borderStrong)
                    .frame(height: AppSize.borderStrong)

                if let error = validationError {
                    Text(error)
                        .font(.system(size: AppTypography.caption, weight: .medium))
                        .foregroundColor(AppColor.textDestructive)
                }
            }
        }
        .padding(.horizontal, AppSpacing.spXlarge)
        .onAppear {
            if focusOnAppear { isNameFocused = true }
        }
    }
}

#if DEBUG
#Preview("名前入力 - 通常") {
    @Previewable @State var name = "HEYBOY01"
    NameInputSection(displayName: $name, validationError: nil, focusOnAppear: false)
}

#Preview("名前入力 - エラー") {
    @Previewable @State var name = "ab"
    NameInputSection(
        displayName: $name,
        validationError: String(localized: "Enter at least 6 characters"),
        focusOnAppear: false
    )
}
#endif
