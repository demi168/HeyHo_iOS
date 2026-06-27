import SwiftUI

// 友だちコード入力モーダル（FriendsList から提示するボトムシート）。
// コード入力 → 招待コードで検索 → 友だち追加 → dismiss までを担う。
// 以前は MY PAGE 内の AddFriendSectionView が担っていた導線を、専用シートに一本化したもの。
struct AddFriendSheetView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    /// 友達追加成功時のコールバック（追加された友達のIDを渡す）
    var onFriendAdded: ((String) -> Void)?

    @State private var codeInput = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
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
        VStack(spacing: 0) {
            // ヘッダー（ToolBar）は両サイド 16（Figma）。本文は 32
            SheetHeader(title: "ADD FRIENDS", onClose: { dismiss() })
            codeInputSection
                .padding(.horizontal, AppSpacing.spXxlarge)
                .padding(.top, AppSpacing.spXlarge)
            // 入力→SUBMIT 間は 32 固定（Figma）。余ったシート高さは下に逃がす
            submitButton
                .padding(.horizontal, AppSpacing.spXxlarge)
                .padding(.top, AppSpacing.spXxlarge)
            Spacer(minLength: AppSpacing.spXxlarge)
        }
        .padding(.top, AppSpacing.spMedium)
        .background(AppColor.backgroundSecondary)
        .overlay { if isAdding { searchingOverlay } }
        .allowsHitTesting(!isAdding)
        .errorAlert($errorMessage)
        .onAppear {
            // シート表示直後にフォーカスしてキーボードを立ち上げる
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                isCodeFocused = true
            }
        }
    }

    // コード入力: 大型・中央寄せ + アンダーライン + 説明/エラー文
    private var codeInputSection: some View {
        // 説明ラベルは入力欄の「上」に配置（Figma）。エラー時は同位置を赤文字に切替
        VStack(spacing: AppSpacing.spXsmall) {
            Text(validationError ?? "ENTER YOUR FRIEND’S 8-DIGITS CODE")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(validationError != nil ? AppColor.textDestructive : AppColor.textLabel)
                .multilineTextAlignment(.center)
            VStack(spacing: AppSpacing.spXsmall) {
                TextField("", text: $codeInput,
                          prompt: Text(verbatim: "ABC12345").foregroundColor(AppColor.textTertiary))
                    .font(.system(size: AppTypography.hero, weight: .black))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundColor(AppColor.textPrimary)
                    .focused($isCodeFocused)
                    .submitLabel(.go)
                    .onChange(of: codeInput) {
                        // 入力を招待コード形式に正規化（英数のみ・8桁まで・大文字）
                        let normalized = InviteCode.normalizedInput(codeInput)
                        if normalized != codeInput { codeInput = normalized }
                    }
                    .onSubmit { addFriendByCode() }
                Rectangle()
                    .fill(validationError != nil ? AppColor.borderDestructive : AppColor.borderStrong)
                    .frame(height: AppSize.borderStrong)
            }
        }
    }

    private var submitButton: some View {
        PrimaryButton(title: "SUBMIT", isEnabled: isCodeValid && !isAdding) {
            addFriendByCode()
        }
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

    private func addFriendByCode() {
        let code = codeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard InviteCode.isValidFormat(code), let myId = authState.currentUserId else { return }
        isAdding = true
        Task {
            do {
                guard let friendId = try await FirestoreService.shared.getUserIdByInviteCode(code) else {
                    await MainActor.run { isAdding = false; errorMessage = String(localized: "Code not found") }
                    return
                }
                if friendId == myId {
                    await MainActor.run { isAdding = false; errorMessage = String(localized: "This is your own code") }
                    return
                }
                try await FirestoreService.shared.addFriend(userId: myId, friendId: friendId)
                // 成功: haptic + コールバック + 自動 dismiss
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    codeInput = ""
                    isAdding = false
                    onFriendAdded?(friendId)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = FirestoreService.isAlreadyFriendsError(error)
                        ? String(localized: "Already friends")
                        : error.localizedDescription
                }
            }
        }
    }
}

#if DEBUG
#Preview("AddFriendSheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddFriendSheetView()
                .environmentObject(AuthState())
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
}
#endif
