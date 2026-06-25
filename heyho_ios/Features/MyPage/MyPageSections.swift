import SwiftUI

// MyPageView の各セクション（純粋 UI・プレビュー可能）。
// EnvironmentObject は持たず、値とクロージャで受け取る

// MARK: - プロフィール表示

struct ProfileSectionView: View {
    let user: AppUser?
    let isPremium: Bool
    let onEditProfile: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.spLarge) {
            // アイコン（中央・上部）。常時マウントして初回色変化を消費し、
            // 編集時のスライド演出が正しく発火する（FriendsView ヘッダーと同じ挙動）
            HeyBoyIconView(
                iconColorValue: user.map { IconColorValue(firestoreString: $0.iconColor) }
                    ?? .solid(hex: AppColor.defaultIconHex),
                size: AppSize.iconLarge,
                showPremiumBadge: isPremium
            )

            // 名前ブロック（左寄せ）
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // EDIT PROFILE（黒塗りフル幅）
            PrimaryButton(title: "EDIT PROFILE") {
                onEditProfile()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 招待コードセクション

struct InviteCodeSectionView: View {
    let inviteCode: String?
    let isLoading: Bool
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            Text("MY CODE IS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
            HStack(alignment: .center, spacing: AppSpacing.spLarge) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    UnderlinedText(
                        text: inviteCode ?? "————————",
                        font: .system(size: AppTypography.title, weight: .black)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                CapsuleButton(title: "SHARE", maxWidth: AppSize.capsuleButtonWidth) {
                    onShare()
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
    InviteCodeSectionView(inviteCode: "ABC12345", isLoading: false, onShare: {})
        .padding(AppSpacing.spXlarge)
}

#Preview("InviteCode - ローディング") {
    InviteCodeSectionView(inviteCode: nil, isLoading: true, onShare: {})
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
