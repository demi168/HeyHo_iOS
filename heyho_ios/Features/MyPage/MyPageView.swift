import CoreImage.CIFilterBuiltins
import SafariServices
import SwiftUI

// hex文字列 → Color（モジュール内で共有）
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Color → hex文字列（例: "FF6B6B"）
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - カプセル型ボタン

private struct CapsuleButton: View {
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

private struct UnderlinedText<Trailing: View>: View {
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

// MARK: - MyPageView

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
    @FocusState private var isFriendCodeFocused: Bool

    /// 招待コードバリデーション（英数のみ8文字）
    private var isFriendCodeValid: Bool {
        FirestoreService.isValidInviteCodeFormat(friendCodeInput.trimmingCharacters(in: .whitespaces))
    }

    /// 招待コードのバリデーションエラー（空欄時は非表示）
    private var friendCodeValidationError: String? {
        let code = friendCodeInput.trimmingCharacters(in: .whitespaces)
        if code.isEmpty { return nil }
        if !code.allSatisfy(FirestoreService.isInviteCodeCharacter) {
            return String(localized: "Only alphanumeric characters allowed")
        }
        if code.count < FirestoreService.inviteCodeLength {
            return String(localized: "Enter exactly 8 characters")
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.spXxlarge) {
                    profileSection
                    inviteCodeSection
                    addFriendSection
                    settingsSection.padding(.top, AppSpacing.spSmall)
                }
                .padding(.horizontal, AppSpacing.spXlarge)
                .padding(.bottom, 40)
            }
        }
        .overlay {
            if isAddingFriend {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: AppSpacing.spSmall) {
                            ProgressView().tint(.white)
                            Text("SEARCHING...")
                                .font(.system(size: AppTypography.label, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isAddingFriend)
        .background(AppColor.backgroundSecondary)
        .onAppear {
            loadUser()
            loadInviteCode()
            if focusAddFriend {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFriendCodeFocused = true
                }
            }
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

    // MARK: - サブビュー

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

    private var profileSection: some View {
        HStack(alignment: .center, spacing: AppSpacing.spLarge) {
            if let user = currentUser {
                HeyBoyIconView(
                    iconColorValue: IconColorValue(firestoreString: user.iconColor),
                    size: AppSize.iconLarge,
                    showPremiumBadge: storeService.isPremium
                )
            } else {
                Circle()
                    .fill(Color.black)
                    .frame(width: AppSize.iconLarge, height: AppSize.iconLarge)
            }

            VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
                Text("MY NAME IS")
                    .font(.system(size: AppTypography.label, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                Text(currentUser?.displayName ?? "——————")
                    .font(.system(size: AppTypography.title, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                Rectangle()
                    .fill(AppColor.borderStrong)
                    .frame(height: AppSize.borderStrong)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer()
                CapsuleButton(title: "EDIT PROFILE", maxWidth: .infinity) {
                    showEditProfile = true
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            Text("MY CODE IS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
            HStack(alignment: .center) {
                if isLoadingInviteCode {
                    ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    UnderlinedText(
                        text: inviteCode ?? "————————",
                        font: .system(size: AppTypography.title, weight: .black)
                    ) {
                        Button(action: { showQRCode = true }) {
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
                    shareInviteCode()
                }
            }
        }
    }

    private var addFriendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXsmall) {
            Text("ADD FRIENDS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)
            HStack(alignment: .center) {
                VStack(spacing: AppSpacing.spXsmall) {
                    TextField("FRIEND'S CODE", text: $friendCodeInput,
                             prompt: Text("FRIEND'S CODE").foregroundColor(AppColor.textTertiary))
                        .font(.system(size: AppTypography.title, weight: .black))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundColor(AppColor.textPrimary)
                        .focused($isFriendCodeFocused)
                        .onChange(of: friendCodeInput) {
                            let filtered = String(friendCodeInput
                                .filter(FirestoreService.isInviteCodeCharacter)
                                .prefix(FirestoreService.inviteCodeLength)).uppercased()
                            if filtered != friendCodeInput { friendCodeInput = filtered }
                        }
                    Rectangle()
                        .fill(friendCodeValidationError != nil ? Color.red : AppColor.borderStrong)
                        .frame(height: AppSize.borderStrong)
                    if let error = friendCodeValidationError {
                        Text(error)
                            .font(.system(size: AppTypography.caption, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CapsuleButton(title: "ADD", maxWidth: AppSize.capsuleButtonWidth) {
                    addFriendByCode()
                }
                .disabled(!isFriendCodeValid || isAddingFriend)
                .opacity(!isFriendCodeValid || isAddingFriend ? 0.4 : 1)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spXxlarge) {
            // 課金導線（プレミアム状態表示・アップグレードボタン）は課金有効時のみ表示
            if PremiumConfig.isEnabled {
                if storeService.isPremium {
                    HStack(spacing: AppSpacing.spSmall) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(AppColor.interactivePrimary)
                        Text("PREMIUM")
                            .font(.system(size: AppTypography.body, weight: .black))
                            .foregroundColor(AppColor.interactivePrimary)
                    }
                    #if DEBUG
                    Button(action: { storeService.debugRevokePremium() }) {
                        Text("DEBUG: REVOKE PREMIUM")
                            .font(.system(size: AppTypography.body, weight: .black))
                            .foregroundColor(.orange)
                    }
                    #endif
                } else {
                    Button(action: { showPaywall = true }) {
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

            Button(action: { safariURL = AppURL.privacy }) {
                Text("PRIVACY POLICY")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { safariURL = AppURL.terms }) {
                Text("TERMS")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { safariURL = AppURL.commercial }) {
                Text("LEGAL INFORMATION")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { signOut() }) {
                Text("SIGN OUT")
                    .font(.system(size: AppTypography.body, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
            }
            Button(action: { deleteAccount() }) {
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

    // MARK: - データ読み込み

    private func loadUser() {
        guard let uid = authState.currentUserId else { return }
        Task {
            if let user = try? await FirestoreService.shared.getUser(userId: uid) {
                await MainActor.run { currentUser = user }
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
        guard isFriendCodeValid, let myId = authState.currentUserId else { return }
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

    private func signOut() {
        showSignOutConfirmation = true
    }

    private func performSignOut() {
        do {
            try authState.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() {
        showDeleteConfirmation = true
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

// MARK: - アプリ内ブラウザ

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - QRコード表示シート

private struct InviteQRCodeView: View {
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
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
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
