import SwiftUI

/// HeyBoy アイコンビュー
/// Figma: EyeIcon (node: 15:419), 48px コンテナ基準
///
/// レイヤー構造:
///   1. 黒背景 Circle (#000)
///   2. HeyBoyBody_default（template SVG → bodyColor で着色、またはグラデーション）
///      inset [20.45%, -38.81%, -37.41%, 18.18%] → width=1.206s, height=1.170s
///      center offset: (+0.285s, +0.289s)
///   3. HeyBoyEyes_default（固定色 SVG）
///      inset [13.05%, 59.75%, 62.6%, 6.02%] 内の eyes
///      center offset: (-0.039s, 0)
///   4. showBackground 時は clipShape(Circle()) で全体をクリップ

struct HeyBoyIconView: View {
    var iconColorValue: IconColorValue
    var size: CGFloat = 48
    var animated: Bool = true
    var showBackground: Bool = true
    var showPremiumBadge: Bool = false
    /// AngularGradient の中心点（UnitPoint）
    var gradientCenter: UnitPoint = UnitPoint(x: 0.34, y: 0.32)

    private static let eyesPatterns: [String] = [
        "HeyBoyEyes_default",
        "HeyBoyEyes_down",
        "HeyBoyEyes_left",
        "HeyBoyEyes_up",
        "HeyBoyEyes_blink",
    ]

    @State private var currentEyes: String = "HeyBoyEyes_default"
    @State private var eyesTimer: Timer?
    @State private var displayedColor: Color
    @State private var slideOffset: CGFloat = 0
    @State private var hasAppearedWithColor = false

    // MARK: - 後方互換イニシャライザ（Color）

    init(bodyColor: Color, size: CGFloat = 48, animated: Bool = true, showBackground: Bool = true, showPremiumBadge: Bool = false, gradientCenter: UnitPoint = UnitPoint(x: 0.34, y: 0.32)) {
        self.iconColorValue = .solid(hex: bodyColor.toHex() ?? "defaultIconYellow")
        self.size = size
        self.animated = animated
        self.showBackground = showBackground
        self.showPremiumBadge = showPremiumBadge
        self.gradientCenter = gradientCenter
        self._displayedColor = State(initialValue: bodyColor)
    }

    // MARK: - IconColorValue イニシャライザ

    init(iconColorValue: IconColorValue, size: CGFloat = 48, animated: Bool = true, showBackground: Bool = true, showPremiumBadge: Bool = false, gradientCenter: UnitPoint = UnitPoint(x: 0.34, y: 0.32)) {
        self.iconColorValue = iconColorValue
        self.size = size
        self.animated = animated
        self.showBackground = showBackground
        self.showPremiumBadge = showPremiumBadge
        self.gradientCenter = gradientCenter
        switch iconColorValue {
        case .solid(let hex):
            self._displayedColor = State(initialValue: Color(hex: hex) ?? AppColor.defaultIconYellow)
        case .gradient:
            self._displayedColor = State(initialValue: .clear)
        }
    }

    // ボディのサイズ・位置（中心基準）
    private var bodySize: CGFloat { size * 1.1 }
    private var bodyOffset: CGPoint { CGPoint(x: size * 0.229, y: size * 0.229) }

    // 目のサイズ・位置（ボディ中心からの相対オフセット）
    private var eyesSize: CGFloat { size * 0.375 }
    private var eyesRelativeOffset: CGPoint { CGPoint(x: -size * 0.268, y: -size * 0.229) }

    var body: some View {
        ZStack {
            // 1. 黒背景
            if showBackground {
                Circle()
                    .fill(Color.black)
            }

            // 2. ボディ
            bodyView
                .frame(width: bodySize, height: bodySize)
                .offset(
                    x: bodyOffset.x + slideOffset,
                    y: bodyOffset.y + slideOffset
                )

            // 3. 目（ボディ中心からの相対位置）
            Image(currentEyes)
                .resizable()
                .scaledToFit()
                .frame(width: eyesSize, height: eyesSize)
                .offset(
                    x: bodyOffset.x + eyesRelativeOffset.x + slideOffset,
                    y: bodyOffset.y + eyesRelativeOffset.y + slideOffset
                )
        }
        .frame(width: size, height: size)
        .if(showBackground) { view in
            view.clipShape(Circle())
        }
        .overlay(alignment: .topTrailing) {
            if showPremiumBadge {
                Image("Icon_Blitz")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.36, height: size * 0.36)
                    .offset(x: size * 0.05, y: -size * 0.05)
            }
        }
        .onAppear {
            startAnimationIfNeeded()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: iconColorValue) { newValue in
            handleColorValueChange(newValue)
        }
    }

    // MARK: - ボディ描画（ソリッド / グラデーション）

    @ViewBuilder
    private var bodyView: some View {
        switch iconColorValue {
        case .solid:
            Image("HeyBoyBody_default")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(displayedColor)
        case .gradient(let presetId):
            if let preset = AppColor.gradientPresets.first(where: { $0.id == presetId }) {
                AnimatedGradientFill(preset: preset, animated: animated, center: gradientCenter)
                    .mask(
                        Image("HeyBoyBody_default")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                    )
            }
        }
    }

    // MARK: - 目のアニメーション

    private func startAnimationIfNeeded() {
        guard animated else { return }
        scheduleNextEyes()
    }

    private func scheduleNextEyes() {
        eyesTimer?.invalidate()
        let isBlink = currentEyes == "HeyBoyEyes_blink"
        let interval: TimeInterval = isBlink ? 0.10 : 2.0
        eyesTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [self] _ in
            guard animated else { return }
            let next = Self.eyesPatterns.randomElement() ?? "HeyBoyEyes_default"
            withAnimation(.easeInOut(duration: 0.10)) {
                currentEyes = next
            }
            scheduleNextEyes()
        }
    }

    private func stopAnimation() {
        eyesTimer?.invalidate()
        eyesTimer = nil
        currentEyes = "HeyBoyEyes_default"
    }

    // MARK: - カラー変更ハンドリング

    private func handleColorValueChange(_ newValue: IconColorValue) {
        switch newValue {
        case .solid(let hex):
            let newColor = Color(hex: hex) ?? AppColor.defaultIconYellow
            if hasAppearedWithColor {
                animateColorChange(to: newColor)
            } else {
                displayedColor = newColor
                hasAppearedWithColor = true
            }
        case .gradient:
            hasAppearedWithColor = true
        }
    }

    /// bodyColor が変わったとき: body+目を右下へスライドアウト → 新色で右下からスライドイン
    private func animateColorChange(to newColor: Color) {
        guard newColor != displayedColor else { return }
        let travel = size * 0.6

        withAnimation(.easeIn(duration: 0.2)) {
            slideOffset = travel
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            displayedColor = newColor

            withAnimation(.easeOut(duration: 0.2)) {
                slideOffset = 0
            }
        }
    }
}

// MARK: - 条件付き modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - プレビュー

#Preview("ソリッド") {
    HStack(spacing: AppSpacing.itemGap) {
        HeyBoyIconView(bodyColor: AppColor.defaultIconCyan, size: AppSize.iconDefault)
        HeyBoyIconView(bodyColor: Color(red: 1.0, green: 0.176, blue: 0.333), size: AppSize.iconDefault)
        HeyBoyIconView(bodyColor: Color(red: 0.796, green: 0.188, blue: 0.878), size: AppSize.iconDefault)
        HeyBoyIconView(bodyColor: Color(red: 1.0, green: 0.553, blue: 0.157), size: AppSize.iconDefault)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("グラデーション") {
    HStack(spacing: AppSpacing.itemGap) {
        HeyBoyIconView(iconColorValue: .gradient(presetId: "sunset"), size: AppSize.iconDefault)
        HeyBoyIconView(iconColorValue: .gradient(presetId: "ocean"), size: AppSize.iconDefault)
        HeyBoyIconView(iconColorValue: .gradient(presetId: "aurora"), size: AppSize.iconDefault)
        HeyBoyIconView(iconColorValue: .gradient(presetId: "neon"), size: AppSize.iconDefault)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

/// グラデーション中心点調整用のインタラクティブプレビュー
private struct GradientCenterPreview: View {
    @State private var centerX: Double = 0.5
    @State private var centerY: Double = 0.5
    @State private var selectedPreset: String = "sunset"

    private let presets = AppColor.gradientPresets

    var body: some View {
        VStack(spacing: 16) {
            Picker("プリセット", selection: $selectedPreset) {
                ForEach(presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // 大きく表示
            HeyBoyIconView(
                iconColorValue: .gradient(presetId: selectedPreset),
                size: 120,
                gradientCenter: UnitPoint(x: centerX, y: centerY)
            )

            // スライダーで中心点を調整
            VStack(spacing: 8) {
                HStack {
                    Text("X: \(centerX, specifier: "%.2f")")
                        .font(.caption).monospacedDigit()
                    Slider(value: $centerX, in: 0...1)
                }
                HStack {
                    Text("Y: \(centerY, specifier: "%.2f")")
                        .font(.caption).monospacedDigit()
                    Slider(value: $centerY, in: 0...1)
                }
            }
            .padding(.horizontal)

            // プリセットの比較（左上中心 vs デフォルト中心）
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    HeyBoyIconView(
                        iconColorValue: .gradient(presetId: selectedPreset),
                        size: 88,
                        gradientCenter: UnitPoint(x: centerX, y: centerY)
                    )
                    Text("カスタム")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                VStack(spacing: 4) {
                    HeyBoyIconView(
                        iconColorValue: .gradient(presetId: selectedPreset),
                        size: 88,
                        gradientCenter: .center
                    )
                    Text("center")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                VStack(spacing: 4) {
                    HeyBoyIconView(
                        iconColorValue: .gradient(presetId: selectedPreset),
                        size: 88,
                        gradientCenter: .topLeading
                    )
                    Text("topLeading")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(AppColor.backgroundPrimary)
    }
}

#Preview("グラデーション中心点調整") {
    GradientCenterPreview()
}
