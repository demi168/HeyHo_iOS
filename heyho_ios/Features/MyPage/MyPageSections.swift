import SwiftUI

// MyPageView の各セクション（純粋 UI・プレビュー可能）。
// EnvironmentObject は持たず、値とクロージャで受け取る

// MARK: - プロフィール表示

struct ProfileSectionView: View {
    let user: AppUser?
    let isPremium: Bool
    let onEditProfile: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.spLarge) {
            if let user {
                HeyBoyIconView(
                    iconColorValue: IconColorValue(firestoreString: user.iconColor),
                    size: AppSize.iconLarge,
                    showPremiumBadge: isPremium
                )
            } else {
                Circle()
                    .fill(AppColor.iconDefault)
                    .frame(width: AppSize.iconLarge, height: AppSize.iconLarge)
            }

            VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
                Text("MY NAME IS")
                    .font(.system(size: AppTypography.label, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                Text(user?.displayName ?? "——————")
                    .font(.system(size: AppTypography.title, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle()
                    .fill(AppColor.borderStrong)
                    .frame(height: AppSize.borderStrong)
                Spacer()
                CapsuleButton(title: "EDIT PROFILE", maxWidth: .infinity) {
                    onEditProfile()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 招待コードセクション

struct InviteCodeSectionView: View {
    let inviteCode: String?
    let isLoading: Bool
    let onShowQRCode: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            Text("MY CODE IS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
            HStack(alignment: .center) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    UnderlinedText(
                        text: inviteCode ?? "————————",
                        font: .system(size: AppTypography.title, weight: .black)
                    ) {
                        Button(action: onShowQRCode) {
                            Image(systemName: "qrcode")
                                .font(.system(size: AppTypography.heading, weight: .bold))
                                .foregroundColor(AppColor.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(inviteCode == nil)
                        .opacity(inviteCode == nil ? 0.4 : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                CapsuleButton(title: "SHARE", maxWidth: AppSize.capsuleButtonWidth) {
                    onShare()
                }
            }
        }
    }
}

// MARK: - 友だち追加（コード入力）

struct AddFriendSectionView: View {
    @Binding var codeInput: String
    let isAdding: Bool
    /// true の場合、表示時に入力欄へフォーカスする
    let focusOnAppear: Bool
    let onAdd: () -> Void

    @FocusState private var isCodeFocused: Bool

    /// 招待コードバリデーション（英数のみ8文字）
    private var isCodeValid: Bool {
        InviteCode.isValidFormat(codeInput.trimmingCharacters(in: .whitespaces))
    }

    /// 招待コードのバリデーションエラー（空欄時は非表示）
    private var validationError: String? {
        let code = codeInput.trimmingCharacters(in: .whitespaces)
        if code.isEmpty { return nil }
        if !code.allSatisfy(InviteCode.isCodeCharacter) {
            return String(localized: "Only alphanumeric characters allowed")
        }
        if code.count < InviteCode.length {
            return String(localized: "Enter exactly 8 characters")
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            Text("ADD FRIENDS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
            HStack(alignment: .center) {
                VStack(spacing: AppSpacing.spXsmall) {
                    TextField("FRIEND'S CODE", text: $codeInput,
                             prompt: Text("FRIEND'S CODE").foregroundColor(AppColor.textTertiary))
                        .font(.system(size: AppTypography.title, weight: .black))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundColor(AppColor.textPrimary)
                        .focused($isCodeFocused)
                        .onChange(of: codeInput) {
                            let filtered = String(codeInput
                                .filter(InviteCode.isCodeCharacter)
                                .prefix(InviteCode.length)).uppercased()
                            if filtered != codeInput { codeInput = filtered }
                        }
                    Rectangle()
                        .fill(validationError != nil ? AppColor.borderDestructive : AppColor.borderStrong)
                        .frame(height: AppSize.borderStrong)
                    if let error = validationError {
                        Text(error)
                            .font(.system(size: AppTypography.caption, weight: .medium))
                            .foregroundColor(AppColor.textDestructive)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CapsuleButton(title: "ADD", maxWidth: AppSize.capsuleButtonWidth) {
                    onAdd()
                }
                .disabled(!isCodeValid || isAdding)
                .opacity(!isCodeValid || isAdding ? 0.4 : 1)
            }
        }
        .onAppear {
            if focusOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCodeFocused = true
                }
            }
        }
    }
}

// MARK: - 設定・アカウント

struct SettingsSectionView: View {
    let isPremium: Bool
    let isDeletingAccount: Bool
    let onUpgrade: () -> Void
    let onDebugRevokePremium: () -> Void
    let onOpenLink: (URL) -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXxlarge) {
            // 課金導線（プレミアム状態表示・アップグレードボタン）は課金有効時のみ表示
            if PremiumConfig.isEnabled {
                if isPremium {
                    HStack(spacing: AppSpacing.spSmall) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(AppColor.interactivePrimary)
                        Text("PREMIUM")
                            .font(.system(size: AppTypography.body, weight: .black))
                            .foregroundColor(AppColor.interactivePrimary)
                    }
                    #if DEBUG
                    Button(action: onDebugRevokePremium) {
                        Text("DEBUG: REVOKE PREMIUM")
                            .font(.system(size: AppTypography.body, weight: .black))
                            .foregroundColor(.orange)
                    }
                    #endif
                } else {
                    Button(action: onUpgrade) {
                        Text("LET'S GO PREMIUM")
                            .font(.system(size: AppTypography.body, weight: .bold))
                            .foregroundColor(AppColor.iconInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.spLarge)
                            .background(AppColor.interactivePrimary)
                            .clipShape(Capsule())
                    }
                }
            }

            Button(action: { onOpenLink(AppURL.privacy) }) {
                Text("PRIVACY POLICY")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { onOpenLink(AppURL.terms) }) {
                Text("TERMS")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { onOpenLink(AppURL.commercial) }) {
                Text("LEGAL INFORMATION")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: onSignOut) {
                Text("SIGN OUT")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: onDeleteAccount) {
                if isDeletingAccount {
                    ProgressView()
                } else {
                    Text("DELETE ACCOUNT")
                        .font(.system(size: AppTypography.body, weight: .black))
                        .foregroundColor(AppColor.textDestructive)
                }
            }
            .disabled(isDeletingAccount)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Profile - 通常") {
    ProfileSectionView(
        user: AppUser(displayName: "HEYBOY01", iconColor: "FFCC00"),
        isPremium: false,
        onEditProfile: {}
    )
    .padding(AppSpacing.spXlarge)
}

#Preview("Profile - 未読込") {
    ProfileSectionView(user: nil, isPremium: false, onEditProfile: {})
        .padding(AppSpacing.spXlarge)
}

#Preview("InviteCode - 取得済み") {
    InviteCodeSectionView(inviteCode: "ABC12345", isLoading: false, onShowQRCode: {}, onShare: {})
        .padding(AppSpacing.spXlarge)
}

#Preview("InviteCode - ローディング") {
    InviteCodeSectionView(inviteCode: nil, isLoading: true, onShowQRCode: {}, onShare: {})
        .padding(AppSpacing.spXlarge)
}

#Preview("AddFriend") {
    @Previewable @State var code = "ABC1"
    AddFriendSectionView(codeInput: $code, isAdding: false, focusOnAppear: false, onAdd: {})
        .padding(AppSpacing.spXlarge)
}

#Preview("Settings") {
    SettingsSectionView(
        isPremium: false,
        isDeletingAccount: false,
        onUpgrade: {},
        onDebugRevokePremium: {},
        onOpenLink: { _ in },
        onSignOut: {},
        onDeleteAccount: {}
    )
    .padding(AppSpacing.spXlarge)
}
#endif
