import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    /// 初回セットアップモード（×ボタン非表示、dismiss不可）
    var isInitialSetup: Bool = false

    @State private var displayName = ""
    @State private var originalDisplayName = ""
    @State private var selectedColorValue: IconColorValue = .solid(hex: "FFD700")
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var nameValidationError: String?
    @State private var showPaywall = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.itemGap), count: 6)

    /// 名前バリデーション: 英数半角のみ6〜22文字、記号不可
    private var isNameValid: Bool {
        return Self.validateDisplayName(displayName) == nil
    }

    /// バリデーション結果を返す（nil = 有効、String = エラーメッセージ）
    private static func validateDisplayName(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "名前を入力してください" }
        if name.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) == nil {
            return "英数字のみ使用できます"
        }
        if name.count < 6 { return "6文字以上で入力してください" }
        if name.count > 22 { return "22文字以内で入力してください" }
        return nil
    }

    /// ソリッドカラーが選択中かどうか
    private func isSolidSelected(_ hex: String) -> Bool {
        if case .solid(let h) = selectedColorValue, h == hex { return true }
        return false
    }

    /// グラデーションが選択中かどうか
    private func isGradientSelected(_ id: String) -> Bool {
        if case .gradient(let gid) = selectedColorValue, gid == id { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: AppSpacing.inlineGap)

            // ヘッダー
            ZStack {
                Text(isInitialSetup ? "SET UP PROFILE" : "EDIT PROFILE")
                    .font(.system(size: AppTypography.body, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)

                HStack {
                    // ×ボタン（初回セットアップ時は非表示）
                    if !isInitialSetup {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: AppTypography.body, weight: .bold))
                                .foregroundColor(AppColor.iconInverse)
                                .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                                .background(Color(white: 0.8))
                                .clipShape(Circle())
                        }
                    }

                    Spacer()

                    // ✓保存ボタン
                    Button(action: { save() }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColor.iconInverse)
                            .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                            .background(isNameValid
                                ? AppColor.interactivePrimary
                                : AppColor.interactivePrimary.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .disabled(isSaving || !isNameValid)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.inlineGap)
            .padding(.bottom, AppSpacing.pageVertical)

            ScrollView {
                VStack(spacing: AppSpacing.pageHorizontal) {
                    // HeyBoyアイコン
                    HeyBoyIconView(
                        iconColorValue: selectedColorValue,
                        size: AppSize.iconLarge,
                        showPremiumBadge: storeService.isPremium
                    )
                    .padding(.top, AppSpacing.pageVertical)

                    // MY NAME IS
                    VStack(alignment: .leading, spacing: AppSpacing.inlineGap) {
                        Text("MY NAME IS")
                            .font(.system(size: AppTypography.label, weight: .bold))
                            .foregroundColor(AppColor.textSecondary)

                        VStack(spacing: AppSpacing.compactGap) {
                            TextField("6-22 characters", text: $displayName)
                                .font(.system(size: AppTypography.title, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: displayName) { _ in validateName() }
                            Rectangle()
                                .fill(nameValidationError != nil
                                    ? Color.red
                                    : AppColor.borderStrong)
                                .frame(height: AppSize.borderStrong)

                            if let error = nameValidationError {
                                Text(error)
                                    .font(.system(size: AppTypography.caption, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)

                    // カラーパレット（ソリッド12色、6×2）
                    LazyVGrid(columns: columns, spacing: AppSpacing.itemGap) {
                        ForEach(Array(AppColor.iconPresets.enumerated()), id: \.element.hex) { index, preset in
                            let isLocked = index >= PremiumConfig.freeColorCount && !storeService.isPremium
                            Button(action: {
                                if isLocked {
                                    showPaywall = true
                                } else {
                                    selectedColorValue = .solid(hex: preset.hex)
                                }
                            }) {
                                Circle()
                                    .fill(Color(hex: preset.hex) ?? .gray)
                                    .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                Color.gray.opacity(0.5),
                                                lineWidth: isSolidSelected(preset.hex) ? 3 : 0
                                            )
                                            .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                                    )
                                    .overlay(
                                        isLocked ? Image(systemName: "lock.fill")
                                            .font(.system(size: AppTypography.caption))
                                            .foregroundColor(.white.opacity(0.9))
                                        : nil
                                    )
                                    .opacity(isLocked ? 0.5 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)

                    // グラデーションパレット（プレミアム専用、6パターン）
                    VStack(alignment: .leading, spacing: AppSpacing.inlineGap) {
                        Text("GRADIENTS")
                            .font(.system(size: AppTypography.label, weight: .bold))
                            .foregroundColor(AppColor.textSecondary)

                        LazyVGrid(columns: columns, spacing: AppSpacing.itemGap) {
                            ForEach(AppColor.gradientPresets) { preset in
                                let isLocked = !storeService.isPremium
                                Button(action: {
                                    if isLocked {
                                        showPaywall = true
                                    } else {
                                        selectedColorValue = .gradient(presetId: preset.id)
                                    }
                                }) {
                                    let colors = preset.hexStops.compactMap { Color(hex: $0) }
                                    Circle()
                                        .fill(
                                            AngularGradient(
                                                colors: colors + [colors.first ?? .clear],
                                                center: .center
                                            )
                                        )
                                        .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    Color.gray.opacity(0.5),
                                                    lineWidth: isGradientSelected(preset.id) ? 3 : 0
                                                )
                                                .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                                        )
                                        .overlay(
                                            isLocked ? Image(systemName: "lock.fill")
                                                .font(.system(size: AppTypography.caption))
                                                .foregroundColor(.white.opacity(0.9))
                                            : nil
                                        )
                                        .opacity(isLocked ? 0.5 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)

                    // プレミアム動線
                    if !storeService.isPremium {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: AppSpacing.inlineGap) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: AppTypography.label))
                                Text("UNLOCK ALL COLORS")
                                    .font(.system(size: AppTypography.label, weight: .bold))
                            }
                            .foregroundColor(AppColor.interactivePrimary)
                        }
                        .buttonStyle(.plain)
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
        .errorAlert($errorMessage)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeService)
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
            if let user = try? await FirestoreService.shared.getUser(userId: uid) {
                await MainActor.run {
                    displayName = user.displayName
                    originalDisplayName = user.displayName
                    selectedColorValue = IconColorValue(firestoreString: user.iconColor)
                }
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
        Task {
            defer { Task { await MainActor.run { isSaving = false } } }
            do {
                // 初回セットアップ時は createProfile（createdAt をセット）、
                // それ以降は updateDisplayName（createdAt を上書きしない）
                if isInitialSetup {
                    try await authState.createProfile(name)
                } else if name != originalDisplayName {
                    try await authState.updateDisplayName(name)
                }
                try await FirestoreService.shared.updateIconColor(userId: uid, colorHex: selectedColorValue.firestoreString)
                await MainActor.run {
                    if isInitialSetup {
                        authState.markProfileSetupComplete()
                    }
                    dismiss()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
