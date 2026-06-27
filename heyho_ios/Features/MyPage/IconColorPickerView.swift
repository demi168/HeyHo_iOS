import SwiftUI

// MARK: - アイコンカラーセレクタ（EditProfileView 用・純粋 UI）
// ソリッドカラー・グラデーションのプリセットグリッドとランダム生成ボタンを持つ。
// プレミアムロック中の選択は onRequestPaywall で親に通知する

struct IconColorPickerView: View {
    @Binding var selectedColorValue: IconColorValue
    let isPremium: Bool
    /// カラー変更アニメーション中はグリッドのタップを無効化する
    let isColorAnimating: Bool
    let onRequestPaywall: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.spMedium), count: 6)

    /// ランダムボタンの虹色プレビュー（装飾の固定値。トークン化対象外）
    private let solidWheelColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .red]
    private let gradientWheelColors: [Color] = [.red, .green, .blue, .red]

    var body: some View {
        VStack(spacing: AppSpacing.spXlarge) {
            solidColorSection
            // グラデーションは課金有効時のみ表示
            if PremiumConfig.isEnabled {
                gradientSection
            }
        }
    }

    // MARK: - 選択状態の判定

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

    // MARK: - セクション

    private var solidColorSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.spSmall) {
            Text("HEYBOY COLORS")
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
                        && !freeHexSet.contains(preset.hex) && !isPremium
                    Button(action: {
                        if isLocked { onRequestPaywall() }
                        else { selectedColorValue = .solid(hex: preset.hex) }
                    }) {
                        Circle()
                            .fill(Color(hex: preset.hex) ?? .gray)
                            .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                            .overlay(
                                Circle()
                                    .stroke(AppColor.selectionRing,
                                            lineWidth: isSolidSelected(preset.hex) ? 3 : 0)
                                    .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                            )
                            .overlay(
                                isLocked ? Image(systemName: "lock.fill")
                                    .font(.system(size: AppTypography.caption))
                                    .foregroundColor(AppColor.iconOnAccent)
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
                    let isLocked = !isPremium
                    Button(action: {
                        if isLocked { onRequestPaywall() }
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
                                    .stroke(AppColor.selectionRing,
                                            lineWidth: isGradientSelected(preset.id) ? 3 : 0)
                                    .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                            )
                            .overlay(
                                isLocked ? Image(systemName: "lock.fill")
                                    .font(.system(size: AppTypography.caption))
                                    .foregroundColor(AppColor.iconOnAccent)
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

    // MARK: - ランダムボタン

    /// ソリッドカラー用ランダムボタン（プレミアム専用）
    private var randomSolidButton: some View {
        Button(action: {
            if !isPremium {
                onRequestPaywall()
            } else {
                selectedColorValue = .solid(hex: Self.generateRandomSolidHex())
            }
        }) {
            Circle()
                .fill(
                    AngularGradient(colors: solidWheelColors, center: .center)
                )
                .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                .overlay(
                    Image(systemName: isPremium ? "dice.fill" : "lock.fill")
                        .font(.system(size: AppTypography.caption))
                        .foregroundColor(AppColor.iconOnAccent)
                )
                .overlay(
                    Circle()
                        .stroke(
                            AppColor.selectionRing,
                            lineWidth: isRandomSolidSelected ? 3 : 0
                        )
                        .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                )
                .opacity(isPremium ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }

    /// グラデーション用ランダムボタン
    private var randomGradientButton: some View {
        Button(action: {
            if !isPremium {
                onRequestPaywall()
            } else {
                selectedColorValue = .customGradient(hexStops: Self.generateRandomHexStops())
            }
        }) {
            Circle()
                .fill(
                    AngularGradient(colors: gradientWheelColors, center: .center)
                )
                .frame(width: AppSize.iconDefault, height: AppSize.iconDefault)
                .overlay(
                    Image(systemName: isPremium ? "dice.fill" : "lock.fill")
                        .font(.system(size: AppTypography.caption))
                        .foregroundColor(AppColor.iconOnAccent)
                )
                .overlay(
                    Circle()
                        .stroke(
                            AppColor.selectionRing,
                            lineWidth: isCustomGradientSelected ? 3 : 0
                        )
                        .frame(width: AppSize.buttonHeight, height: AppSize.buttonHeight)
                )
                .opacity(isPremium ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - ランダムカラー生成

    /// 鮮やかなランダム hex を1色生成（HSB: H=全域, S=0.7〜1.0, B=0.8〜1.0）
    private static func generateRandomSolidHex() -> String {
        hsbToHex(h: Double.random(in: 0...1), s: Double.random(in: 0.7...1.0), b: Double.random(in: 0.8...1.0))
    }

    /// HSB → hex 文字列に変換
    private static func hsbToHex(h: Double, s: Double, b: Double) -> String {
        let c = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        c.getRed(&r, green: &g, blue: &bl, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(bl * 255))
    }

    /// 色彩調和に基づく3色グラデーションをランダム生成
    /// 補色・類似色・トライアドのいずれかのパターンでベース色から残り2色を決定
    private static func generateRandomHexStops() -> [String] {
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
}

#if DEBUG
#Preview("カラーセレクタ - 無料") {
    @Previewable @State var color: IconColorValue = .solid(hex: "FFCC00")
    IconColorPickerView(
        selectedColorValue: $color,
        isPremium: false,
        isColorAnimating: false,
        onRequestPaywall: {}
    )
}

#Preview("カラーセレクタ - プレミアム") {
    @Previewable @State var color: IconColorValue = .solid(hex: "FF2D55")
    IconColorPickerView(
        selectedColorValue: $color,
        isPremium: true,
        isColorAnimating: false,
        onRequestPaywall: {}
    )
}
#endif
