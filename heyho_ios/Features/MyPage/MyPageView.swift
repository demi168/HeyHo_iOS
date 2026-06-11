import SwiftUI

// マイページ画面。データ読み込み・アクションを担当し、
// 各セクションの UI は MyPageSections.swift のサブ View に委譲する

struct MyPageView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    /// true の場合、表示時に友だちコード入力欄にフォーカスする
    var focusAddFriend: Bool = false
    /// 友達追加成功時のコールバック（追加された友達のIDを渡す）
    var onFriendAdded: ((String) -> Void)?

    @State private var currentUser: AppUser?
    @State private var inviteCode: String?
    @State private var isLoadingInviteCode = false
    @State private var friendCodeInput = ""
    @State private var isAddingFriend = false
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
                VStack(alignment: .leading, spacing: AppSpacing.spXxlarge) {
                    ProfileSectionView(
                        user: currentUser,
                        isPremium: storeService.isPremium,
                        onEditProfile: { showEditProfile = true }
                    )
                    InviteCodeSectionView(
                        inviteCode: inviteCode,
                        isLoading: isLoadingInviteCode,
                        onShowQRCode: { showQRCode = true },
                        onShare: shareInviteCode
                    )
                    AddFriendSectionView(
                        codeInput: $friendCodeInput,
                        isAdding: isAddingFriend,
                        focusOnAppear: focusAddFriend,
                        onAdd: addFriendByCode
                    )
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
                    .padding(.top, AppSpacing.spSmall)
                }
                .padding(.horizontal, AppSpacing.spXlarge)
                .padding(.bottom, 40)
            }
        }
        .overlay {
            if isAddingFriend { searchingOverlay }
        }
        .allowsHitTesting(!isAddingFriend)
        .background(AppColor.backgroundSecondary)
        .onAppear {
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
                InviteQRCodeView(inviteCode: code).presentationDetents([.large])
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

    // MARK: - ヘッダー・オーバーレイ

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
        .padding(.horizontal, AppSpacing.spXlarge)
        .padding(.top, AppSpacing.spSmall)
        .padding(.bottom, AppSpacing.spLarge)
    }

    private var searchingOverlay: some View {
        AppColor.overlayScrim
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: AppSpacing.spSmall) {
                    ProgressView().tint(AppColor.iconInverse)
                    Text("SEARCHING...")
                        .font(.system(size: AppTypography.label, weight: .bold))
                        .foregroundColor(AppColor.textInverse)
                }
            }
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

    private func shareInviteCode() {
        guard let code = inviteCode else { return }
        ShareService.shareInviteCode(code)
    }

    private func addFriendByCode() {
        let code = friendCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard InviteCode.isValidFormat(code), let myId = authState.currentUserId else { return }
        isAddingFriend = true
        Task {
            do {
                guard let friendId = try await FirestoreService.shared.getUserIdByInviteCode(code) else {
                    await MainActor.run { isAddingFriend = false; errorMessage = String(localized: "Code not found") }
                    return
                }
                if friendId == myId {
                    await MainActor.run { isAddingFriend = false; errorMessage = String(localized: "This is your own code") }
                    return
                }
                try await FirestoreService.shared.addFriend(userId: myId, friendId: friendId)
                // 成功: haptic + コールバック + 自動dismiss
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    friendCodeInput = ""
                    isAddingFriend = false
                    onFriendAdded?(friendId)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAddingFriend = false
                    errorMessage = FirestoreService.isAlreadyFriendsError(error)
                        ? String(localized: "Already friends")
                        : error.localizedDescription
                }
            }
        }
    }

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
