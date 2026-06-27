import SwiftUI

// マイページ画面。データ読み込み・アクションを担当し、
// 各セクションの UI は MyPageSections.swift のサブ View に委譲する

struct MyPageView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var currentUser: AppUser?
    @State private var inviteCode: String?
    @State private var isLoadingInviteCode = false
    @State private var errorMessage: String?
    @State private var showEditProfile = false
    @State private var showPaywall = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showQRCode = false
    @State private var safariURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProfileSectionView(
                        user: currentUser,
                        isPremium: storeService.isPremium,
                        onEditProfile: { showEditProfile = true }
                    )
                    InviteCodeSectionView(
                        inviteCode: inviteCode,
                        isLoading: isLoadingInviteCode,
                        onShare: { showQRCode = true }
                    )
                    // プロフィール→コード間（Figma 36px → 最寄り 32px）
                    .padding(.top, AppSpacing.spXxlarge)
                    SettingsSectionView(
                        isPremium: storeService.isPremium,
                        isDeletingAccount: isDeletingAccount,
                        onUpgrade: { showPaywall = true },
                        onDebugRevokePremium: {
                            #if DEBUG
                            storeService.debugRevokePremium()
                            #endif
                        },
                        onOpenLink: { safariURL = $0 },
                        onSignOut: { showSignOutConfirmation = true },
                        onDeleteAccount: { showDeleteConfirmation = true }
                    )
                    // コード→メニュー間（Figma 64px）
                    .padding(.top, AppSpacing.spXxxlarge)
                }
                .padding(.horizontal, AppSpacing.spXxlarge)
                .padding(.bottom, 40)
            }
        }
        .background(AppColor.backgroundSecondary)
        .onAppear {
            // キャッシュ済みユーザーで即座に表示を埋め、デフォルト色の一瞬のちらつきを避ける
            if currentUser == nil { currentUser = authState.currentUser }
            loadUser()
            loadInviteCode()
        }
        .errorAlert($errorMessage)
        .sheet(isPresented: $showEditProfile, onDismiss: { loadUser() }) {
            EditProfileView()
                .environmentObject(authState)
                .environmentObject(storeService)
        }
        .sheet(isPresented: $showQRCode) {
            if let code = inviteCode {
                InviteQRCodeView(
                    inviteCode: code,
                    iconColorValue: currentUser.map { IconColorValue(firestoreString: $0.iconColor) }
                        ?? .solid(hex: AppColor.defaultIconHex)
                )
                .presentationDetents([.height(InviteQRCodeView.sheetDetentHeight)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeService)
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) { performSignOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { performDeleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting your account will permanently remove all data. This action cannot be undone.")
        }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        ZStack {
            Text("HELLO,HEY HO")
                .font(.system(size: AppTypography.body, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: AppTypography.body, weight: .bold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                        .background(AppColor.buttonIconBackground)
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, AppSpacing.spLarge)
        .padding(.top, AppSpacing.spSmall)
        .padding(.bottom, AppSpacing.spLarge)
    }

    // MARK: - データ読み込み

    private func loadUser() {
        guard let uid = authState.currentUserId else { return }
        Task {
            do {
                guard let user = try await FirestoreService.shared.getUser(userId: uid) else { return }
                await MainActor.run { currentUser = user }
            } catch {
                // 読込失敗時はキャッシュ済み表示のまま（empty state で可）
                AppLogger.firestore.error("ユーザー読込に失敗: \(error.localizedDescription)")
            }
        }
    }

    private func loadInviteCode() {
        guard let uid = authState.currentUserId else { return }
        isLoadingInviteCode = true
        Task { @MainActor in
            defer { isLoadingInviteCode = false }
            do {
                inviteCode = try await FirestoreService.shared.ensureInviteCode(userId: uid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - アクション

    private func performSignOut() {
        do {
            try authState.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDeleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await authState.deleteAccount()
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
