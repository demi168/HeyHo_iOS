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
    @State private var isColorAnimating = false
    @FocusState private var isNameFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.spMedium), count: 6)

    /// 表示名の文字数制限（grapheme 単位）。
    /// 変更時は Localizable.xcstrings の文言（"6-16 characters" 等）と firestore.rules の isValidDisplayName も合わせること
    private static let nameLengthRange = 6...16

    /// 名前バリデーション: 英数半角・絵文字のみ6〜16文字、記号不可
    private var isNameValid: Bool {
        return Self.validateDisplayName(displayName) == nil
    }

    /// バリデーション結果を返す（nil = 有効、String = エラーメッセージ）
    private static func validateDisplayName(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return String(localized: "Please enter your name") }
        if !name.allSatisfy({ isAllowedCharacter($0) }) {
            return String(localized: "Only alphanumeric characters and emoji allowed")
        }
        if name.range(of: "heyho", options: .caseInsensitive) != nil {
            return String(localized: "Names containing \"heyho\" are not allowed")
        }
        if name.count < nameLengthRange.lowerBound { return String(localized: "Enter at least 6 characters") }
        if name.count > nameLengthRange.upperBound { return String(localized: "Enter 16 characters or less") }
        return nil
    }

    /// 許可文字チェック: ASCII英数字または絵文字のみ
    private static func isAllowedCharacter(_ char: Character) -> Bool {
        if char.isASCII { return char.isLetter || char.isNumber }
        // 非ASCII: 絵文字を含む文字のみ許可（日本語等は除外）
        return char.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0xFF)
        }
    }

    /// ソリッドカラーが選択中かどうか
    private func isSolidSelected(_ hex: String) -> Bool {
        if case .solid(let h) = selectedColorValue, h == hex { return true }
        return false
    }

    /// グラデーションプリセットが選択中かどうか
    private func isGradientSelected(_ id: String) -> Bool {
        if case .gradient(let gid) = selectedColorValue, gid == id { return true }
        return false
    }

    /// カスタムグラデーションが選択中かどうか
    private var isCustomGradientSelected: Bool {
        if case .customGradient = selectedColorValue { return true }
        return false
    }

    /// ランダムソリッドカラーが選択中かどうか（プリセットに含まれないソリッド）
    private var isRandomSolidSelected: Bool {
        guard case .solid(let hex) = selectedColorValue else { return false }
        let allPresetHexes = Set((AppColor.freeIconPresets + AppColor.premiumIconPresets).map(\.hex))
        return !allPresetHexes.contains(hex)
    }

    // MARK: - ランダムボタン

    /// ソリッドカラー用ランダムボタン（プレミアム専用）
    private var randomSolidButton: some View {
        Button(action: {
            if !storeService.isPremium {
                showPaywall = true
            } else {
                selectedColorValue = .solid(hex: generateRandomSolidHex())
            }
        }) {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                .overlay(
                    Image(systemName: storeService.isPremium ? "dice.fill" : "lock.fill")
                        .font(.system(size: AppTypography.caption))
                        .foregroundColor(.white.opacity(0.9))
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.5),
                            lineWidth: isRandomSolidSelected ? 3 : 0
                        )
                        .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                )
                .opacity(storeService.isPremium ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }

    /// グラデーション用ランダムボタン
    private var randomGradientButton: some View {
        Button(action: {
            if !storeService.isPremium {
                showPaywall = true
            } else {
                selectedColorValue = .customGradient(hexStops: generateRandomHexStops())
            }
        }) {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .green, .blue, .red],
                        center: .center
                    )
                )
                .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                .overlay(
                    Image(systemName: storeService.isPremium ? "dice.fill" : "lock.fill")
                        .font(.system(size: AppTypography.caption))
                        .foregroundColor(.white.opacity(0.9))
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.5),
                            lineWidth: isCustomGradientSelected ? 3 : 0
                        )
                        .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                )
                .opacity(storeService.isPremium ? 1 : 0.5)
        }
        .buttonStyle(.plain)
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

                    nameInputSection
                    solidColorSection
                    // グラデーション・アップグレード導線は課金有効時のみ表示
                    if PremiumConfig.isEnabled {
                        gradientSection
                        if !storeService.isPremium { premiumUpgradeSection }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(AppColor.backgroundSecondary)
        .interactiveDismissDisabled(isInitialSetup)
        .onAppear {
            if !isInitialSetup { loadUser() }
            if isInitialSetup { isNameFocused = true }
        }
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
        ZStack {
            Text(isInitialSetup ? "SET UP PROFILE" : "EDIT PROFILE")
                .font(.system(size: AppTypography.body, weight: .bold))
                .foregroundColor(AppColor.textPrimary)

            HStack {
                if !isInitialSetup {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: AppTypography.body, weight: .bold))
                            .foregroundColor(AppColor.iconInverse)
                            .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                            .background(AppColor.buttonIconBackground)
                            .clipShape(Circle())
                    }
                }
                Spacer()
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
        }
        .padding(.horizontal, AppSpacing.spXlarge)
        .padding(.top, AppSpacing.spSmall)
        .padding(.bottom, AppSpacing.spLarge)
    }

    private var nameInputSection: some View {
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
                    .onChange(of: displayName) { validateName() }
                Rectangle()
                    .fill(nameValidationError != nil ? Color.red : AppColor.borderStrong)
                    .frame(height: AppSize.borderStrong)

                if let error = nameValidationError {
                    Text(error)
                        .font(.system(size: AppTypography.caption, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, AppSpacing.spXlarge)
    }

    private var solidColorSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spSmall) {
            Text("SOLID COLORS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)

            // 課金無効時は無料プリセットのみ表示（プレミアム色は非表示）
            let allPresets = PremiumConfig.isEnabled
                ? AppColor.freeIconPresets + AppColor.premiumIconPresets
                : AppColor.freeIconPresets
            let freeHexSet = Set(AppColor.freeIconPresets.map(\.hex))
            LazyVGrid(columns: columns, spacing: AppSpacing.spMedium) {
                ForEach(Array(allPresets.enumerated()), id: \.element.hex) { index, preset in
                    // 課金無効時はプレミアム色自体が表示されないため、ロックは課金有効時のみ成立する
                    let isLocked = PremiumConfig.isEnabled
                        && !freeHexSet.contains(preset.hex) && !storeService.isPremium
                    Button(action: {
                        if isLocked { showPaywall = true }
                        else { selectedColorValue = .solid(hex: preset.hex) }
                    }) {
                        Circle()
                            .fill(Color(hex: preset.hex) ?? .gray)
                            .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.5),
                                            lineWidth: isSolidSelected(preset.hex) ? 3 : 0)
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

                    // ランダム色生成はプレミアム機能（課金有効時のみ）
                    if PremiumConfig.isEnabled && index == allPresets.count - 1 { randomSolidButton }
                }
            }
            .allowsHitTesting(!isColorAnimating)
        }
        .padding(.horizontal, AppSpacing.spXlarge)
    }

    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spSmall) {
            Text("GRADIENTS")
                .font(.system(size: AppTypography.label, weight: .bold))
                .foregroundColor(AppColor.textSecondary)

            LazyVGrid(columns: columns, spacing: AppSpacing.spMedium) {
                ForEach(Array(AppColor.premiumGradientPresets.enumerated()), id: \.element.id) { index, preset in
                    let isLocked = !storeService.isPremium
                    Button(action: {
                        if isLocked { showPaywall = true }
                        else { selectedColorValue = .gradient(presetId: preset.id) }
                    }) {
                        let colors = preset.hexStops.compactMap { Color(hex: $0) }
                        Circle()
                            .fill(AngularGradient(
                                colors: colors + [colors.first ?? .clear],
                                center: .center
                            ))
                            .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.5),
                                            lineWidth: isGradientSelected(preset.id) ? 3 : 0)
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

                    if index == AppColor.premiumGradientPresets.count - 1 { randomGradientButton }
                }
            }
            .allowsHitTesting(!isColorAnimating)
        }
        .padding(.horizontal, AppSpacing.spXlarge)
    }

    private var premiumUpgradeSection: some View {
        VStack(spacing: AppSpacing.spSmall) {
            Text("Unlock infinite colors")
                .font(.system(size: AppTypography.label, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            Button(action: { showPaywall = true }) {
                Text("LET'S GO PREMIUM")
                    .font(.system(size: AppTypography.body, weight: .bold))
                    .foregroundColor(.white)
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
                try? await FirestoreService.shared.updateIconColor(
                    userId: uid,
                    colorHex: selectedColorValue.firestoreString
                )
            }
        }
    }

    // MARK: - ランダムグラデーション生成

    /// 鮮やかなランダム hex を1色生成（HSB: H=全域, S=0.5〜1.0, B=0.6〜1.0）
    private func generateRandomSolidHex() -> String {
        hsbToHex(h: Double.random(in: 0...1), s: Double.random(in: 0.7...1.0), b: Double.random(in: 0.8...1.0))
    }

    /// HSB → hex 文字列に変換
    private func hsbToHex(h: Double, s: Double, b: Double) -> String {
        let c = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        c.getRed(&r, green: &g, blue: &bl, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(bl * 255))
    }

    /// 色彩調和に基づく3色グラデーションをランダム生成
    /// 補色・類似色・トライアドのいずれかのパターンでベース色から残り2色を決定
    private func generateRandomHexStops() -> [String] {
        let baseHue = Double.random(in: 0...1)

        // 配色パターンをランダム選択
        let pattern = Int.random(in: 0...2)
        let hueOffsets: [Double]
        switch pattern {
        case 0:  hueOffsets = [0, 0.5, 0.25]          // 補色 + 中間
        case 1:  hueOffsets = [0, 1.0 / 12, -1.0 / 12] // 類似色 ±30°
        default: hueOffsets = [0, 1.0 / 3, 2.0 / 3]    // トライアド ±120°
        }

        return hueOffsets.map { offset in
            var h = (baseHue + offset).truncatingRemainder(dividingBy: 1.0)
            if h < 0 { h += 1 }
            return hsbToHex(h: h, s: Double.random(in: 0.7...1.0), b: Double.random(in: 0.8...1.0))
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
                    // プレミアム解除済みならデフォルトに戻す
                    if !storeService.isPremium { resetColorIfLockedAndSave() }
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

