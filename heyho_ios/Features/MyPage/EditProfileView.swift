import SwiftUI

// プロフィール編集画面。データ読み込み・保存・バリデーションを担当し、
// 名前入力は NameInputSection、カラー選択は IconColorPickerView に委譲する

struct EditProfileView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    /// 初回セットアップモード（×ボタン非表示、dismiss不可）
    var isInitialSetup: Bool = false

    @State private var displayName = ""
    @State private var originalDisplayName = ""
    @State private var selectedColorValue: IconColorValue = .solid(hex: AppColor.defaultIconHex)
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var nameValidationError: String?
    @State private var showPaywall = false
    @State private var isColorAnimating = false

    /// 名前バリデーション: 英数半角・絵文字のみ6〜16文字、記号不可
    private var isNameValid: Bool {
        return Self.validateDisplayName(displayName) == nil
    }

    /// バリデーション結果をエラーメッセージに変換する（nil = 有効）。
    /// 判定ロジック本体は DisplayNameValidator（テスト対象）にある
    private static func validateDisplayName(_ input: String) -> String? {
        switch DisplayNameValidator.validate(input) {
        case nil: return nil
        case .empty: return String(localized: "Please enter your name")
        case .disallowedCharacter: return String(localized: "Only alphanumeric characters and emoji allowed")
        case .containsReservedWord: return String(localized: "Names containing \"heyho\" are not allowed")
        case .tooShort: return String(localized: "Enter at least 6 characters")
        case .tooLong: return String(localized: "Enter 16 characters or less")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: AppSpacing.spSmall)
            headerView
            ScrollView {
                VStack(spacing: AppSpacing.spXlarge) {
                    HeyBoyIconView(
                        iconColorValue: selectedColorValue,
                        size: AppSize.iconLarge,
                        showPremiumBadge: storeService.isPremium,
                        isColorChanging: $isColorAnimating
                    )
                    .padding(.top, AppSpacing.spLarge)

                    NameInputSection(
                        displayName: $displayName,
                        validationError: nameValidationError,
                        focusOnAppear: isInitialSetup
                    )
                    IconColorPickerView(
                        selectedColorValue: $selectedColorValue,
                        isPremium: storeService.isPremium,
                        isColorAnimating: isColorAnimating,
                        onRequestPaywall: { showPaywall = true }
                    )
                    // アップグレード導線は課金有効時のみ表示
                    if PremiumConfig.isEnabled && !storeService.isPremium {
                        premiumUpgradeSection
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(AppColor.backgroundSecondary)
        .interactiveDismissDisabled(isInitialSetup)
        .onAppear {
            if !isInitialSetup { loadUser() }
        }
        .onChange(of: displayName) { validateName() }
        .onChange(of: storeService.isPremium) {
            if !storeService.isPremium { resetColorIfLockedAndSave() }
        }
        .errorAlert($errorMessage)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeService)
        }
    }

    // MARK: - サブビュー

    private var headerView: some View {
        // 共通 SheetHeader（左クローズ＋右保存）。初回セットアップ時はクローズ非表示
        SheetHeader(
            title: isInitialSetup ? "SET UP PROFILE" : "EDIT PROFILE",
            leading: {
                if !isInitialSetup {
                    SheetCloseButton(iconColor: AppColor.textPrimary) { dismiss() }
                }
            },
            trailing: { saveButton }
        )
        .padding(.top, AppSpacing.spSmall)
        .padding(.bottom, AppSpacing.spLarge)
    }

    /// 保存（✓）ボタン。名前が有効なときのみ活性
    private var saveButton: some View {
        Button(action: { save() }) {
            Image(systemName: "checkmark")
                .font(.system(size: AppTypography.body, weight: .bold))
                .foregroundColor(AppColor.iconInverse)
                .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                .background(isNameValid
                    ? AppColor.interactivePrimary
                    : AppColor.interactivePrimary.opacity(0.4))
                .clipShape(Circle())
        }
        .disabled(isSaving || !isNameValid)
    }

    private var premiumUpgradeSection: some View {
        VStack(spacing: AppSpacing.spSmall) {
            Text("Unlock infinite colors")
                .font(.system(size: AppTypography.label, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            Button(action: { showPaywall = true }) {
                Text("LET'S GO PREMIUM")
                    .font(.system(size: AppTypography.body, weight: .bold))
                    .foregroundColor(AppColor.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.buttonHeight)
                    .background(AppColor.interactivePrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.spXlarge)
    }

    // MARK: - プレミアム解除時のカラーリセット

    /// 現在選択中のカラーがプレミアム専用なら、デフォルト（イエロー）に戻して Firestore にも保存
    private func resetColorIfLockedAndSave() {
        let oldValue = selectedColorValue
        switch selectedColorValue {
        case .gradient, .customGradient:
            selectedColorValue = .solid(hex: AppColor.defaultIconHex)
        case .solid(let hex):
            let freeHexes = Set(AppColor.freeIconPresets.map(\.hex))
            if !freeHexes.contains(hex) {
                selectedColorValue = .solid(hex: AppColor.defaultIconHex)
            }
        }
        // カラーが実際に変わった場合のみ Firestore に保存
        if selectedColorValue != oldValue, let uid = authState.currentUserId {
            Task {
                do {
                    try await FirestoreService.shared.updateIconColor(
                        userId: uid,
                        colorHex: selectedColorValue.firestoreString
                    )
                    await authState.refreshCurrentUser()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - バリデーション

    /// 入力中のリアルタイムバリデーション（空欄時はエラー非表示）
    private func validateName() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            nameValidationError = nil
            return
        }
        nameValidationError = Self.validateDisplayName(displayName)
    }

    // MARK: - データ

    private func loadUser() {
        guard let uid = authState.currentUserId else { return }
        Task {
            do {
                guard let user = try await FirestoreService.shared.getUser(userId: uid) else { return }
                await MainActor.run {
                    displayName = user.displayName
                    originalDisplayName = user.displayName
                    selectedColorValue = IconColorValue(firestoreString: user.iconColor)
                    // プレミアム解除済みならデフォルトに戻す
                    if !storeService.isPremium { resetColorIfLockedAndSave() }
                }
            } catch {
                // 読込失敗時は初期値のまま編集を継続できる（保存時に再度エラー検知される）
                AppLogger.firestore.error("プロフィール読込に失敗: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        guard let uid = authState.currentUserId else { return }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard isNameValid else {
            validateName()
            return
        }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                // 初回セットアップ時は createProfile（createdAt をセット）、
                // それ以降は updateDisplayName（createdAt を上書きしない）
                if isInitialSetup {
                    try await authState.createProfile(name)
                } else if name != originalDisplayName {
                    try await authState.updateDisplayName(name)
                }
                try await FirestoreService.shared.updateIconColor(userId: uid, colorHex: selectedColorValue.firestoreString)
                // authState.currentUser はキャッシュのため、保存内容を反映するには明示的な再取得が要る。
                // これを怠ると FriendsView 側の色・名前表示がアプリ再起動まで更新されない
                await authState.refreshCurrentUser()
                if isInitialSetup {
                    authState.markProfileSetupComplete()
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
