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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.pageVertical)
                .padding(.vertical, AppSpacing.inlineGap)
                .overlay(
                    Capsule()
                        .stroke(AppColor.borderStrong, lineWidth: AppSize.borderUnderline)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 下線付きテキスト

private struct UnderlinedText: View {
    let text: String
    let font: Font

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
            Text(text)
                .font(font)
                .foregroundColor(AppColor.textPrimary)
            Rectangle()
                .fill(AppColor.borderStrong)
                .frame(height: AppSize.borderStrong)
        }
    }
}

// MARK: - MyPageView

struct MyPageView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    /// true の場合、表示時に友だちコード入力欄にフォーカスする
    var focusAddFriend: Bool = false

    @State private var currentUser: AppUser?
    @State private var inviteCode: String?
    @State private var isLoadingInviteCode = false
    @State private var friendCodeInput = ""
    @State private var isAddingFriend = false
    @State private var errorMessage: String?
    @State private var showEditProfile = false
    @State private var showPaywall = false
    @FocusState private var isFriendCodeFocused: Bool

    /// 招待コードの有効な長さ（旧6桁と新8桁の両方を許容）
    private var isFriendCodeValid: Bool {
        let len = friendCodeInput.trimmingCharacters(in: .whitespaces).count
        return len == 6 || len == 8
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
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
                            .background(Color(white: 0.9))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.inlineGap)
            .padding(.bottom, AppSpacing.pageVertical)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    // HeyBoyアイコン + MY NAME IS（横並び）
                    HStack(alignment: .center, spacing: AppSpacing.itemGap) {
                        if let user = currentUser {
                            HeyBoyIconView(
                                iconColorValue: IconColorValue(firestoreString: user.iconColor),
                                size: AppSize.iconLarge,
                                showPremiumBadge: storeService.isPremium
                            )
                        } else {
                            // ユーザー読み込み前は黒円のみ表示
                            Circle()
                                .fill(Color.black)
                                .frame(width: AppSize.iconLarge, height: AppSize.iconLarge)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
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
                            // edit profile ボタン
                            CapsuleButton(title: "edit profile") {
                                showEditProfile = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // MY CODE IS
                    VStack(alignment: .leading, spacing: AppSpacing.inlineGap) {
                        Text("MY CODE IS")
                            .font(.system(size: AppTypography.label, weight: .bold))
                            .foregroundColor(AppColor.textSecondary)

                        HStack(alignment: .bottom) {
                            if isLoadingInviteCode {
                                ProgressView()
                            } else {
                                UnderlinedText(
                                    text: inviteCode ?? "————————",
                                    font: .system(size: AppTypography.title, weight: .black).monospaced()
                                )
                            }
                            Spacer()
                            CapsuleButton(title: "share") {
                                shareInviteCode()
                            }
                        }
                    }

                    // ADD FRIENDS
                    VStack(alignment: .leading, spacing: AppSpacing.inlineGap) {
                        Text("ADD FRIENDS")
                            .font(.system(size: AppTypography.label, weight: .bold))
                            .foregroundColor(AppColor.textSecondary)

                        HStack(alignment: .bottom) {
                            VStack(spacing: AppSpacing.compactGap) {
                                TextField("FRIEND'S CODE", text: $friendCodeInput)
                                    .font(.system(size: AppTypography.title, weight: .black))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .foregroundColor(AppColor.textPrimary)
                                    .focused($isFriendCodeFocused)
                                Rectangle()
                                    .fill(AppColor.borderStrong)
                                    .frame(height: AppSize.borderStrong)
                            }
                            Spacer(minLength: AppSpacing.pageVertical)
                            CapsuleButton(title: "add") {
                                addFriendByCode()
                            }
                            .disabled(!isFriendCodeValid || isAddingFriend)
                            .opacity(!isFriendCodeValid || isAddingFriend ? 0.4 : 1)
                        }
                    }

                    // プレミアム + リンク類
                    VStack(alignment: .leading, spacing: AppSpacing.pageVertical) {
                        if storeService.isPremium {
                            HStack(spacing: AppSpacing.inlineGap) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppColor.interactivePrimary)
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
                                Text("UPGRADE TO PREMIUM")
                                    .font(.system(size: AppTypography.body, weight: .black))
                                    .foregroundColor(AppColor.interactivePrimary)
                            }
                        }

                        Button(action: { restorePurchases() }) {
                            Text("RESTORE PURCHASES")
                                .font(.system(size: AppTypography.body, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                        }

                        Button(action: { openURL("https://example.com/privacy") }) {
                            Text("PRIVACY POLICY")
                                .font(.system(size: AppTypography.body, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                        }

                        Button(action: { openURL("https://example.com/terms") }) {
                            Text("TERMS")
                                .font(.system(size: AppTypography.body, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                        }

                        Button(action: { signOut() }) {
                            Text("SIGN OUT")
                                .font(.system(size: AppTypography.body, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                        }

                        Button(action: { deleteAccount() }) {
                            Text("DELETE ACCOUNT")
                                .font(.system(size: AppTypography.body, weight: .black))
                                .foregroundColor(AppColor.textDestructive)
                        }
                    }
                    .padding(.top, AppSpacing.inlineGap)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.bottom, 40)
            }
        }
        .background(AppColor.backgroundSecondary)
        .onAppear {
            loadUser()
            loadInviteCode()
            if focusAddFriend {
                // キーボード表示のためにわずかに遅延させる
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
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeService)
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
        Task {
            defer { Task { await MainActor.run { isLoadingInviteCode = false } } }
            do {
                let code = try await FirestoreService.shared.ensureInviteCode(userId: uid)
                await MainActor.run { inviteCode = code }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - アクション

    private func shareInviteCode() {
        guard let code = inviteCode else { return }
        let activityVC = UIActivityViewController(
            activityItems: [code],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func addFriendByCode() {
        let code = friendCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard isFriendCodeValid, let myId = authState.currentUserId else { return }
        isAddingFriend = true
        Task {
            defer { Task { await MainActor.run { isAddingFriend = false } } }
            do {
                guard let friendId = try await FirestoreService.shared.getUserIdByInviteCode(code) else {
                    await MainActor.run { errorMessage = "コードが見つかりません" }
                    return
                }
                if friendId == myId {
                    await MainActor.run { errorMessage = "自分のコードです" }
                    return
                }
                try await FirestoreService.shared.addFriend(userId: myId, friendId: friendId)
                await MainActor.run { friendCodeInput = "" }
            } catch {
                let msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
                await MainActor.run { errorMessage = msg == "既に友達です" ? "すでに友だちです" : msg }
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func signOut() {
        do {
            try authState.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePurchases() {
        Task { await storeService.restorePurchases() }
    }

    private func deleteAccount() {
        // TODO: アカウント削除の確認ダイアログと処理を実装
    }
}
