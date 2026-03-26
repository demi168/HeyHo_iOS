import SwiftUI

/// グラデーションプリセットをアニメーション付きで描画するビュー
struct AnimatedGradientFill: View {
    let preset: GradientPreset
    let animated: Bool
    /// AngularGradient の中心点（UnitPoint、デフォルト .center）
    var center: UnitPoint

    @State private var rotation: Double = 0

    init(preset: GradientPreset, animated: Bool = true, center: UnitPoint = .center) {
        self.preset = preset
        self.animated = animated
        self.center = center
    }

    private var colors: [Color] {
        preset.hexStops.compactMap { Color(hex: $0) }
    }

    var body: some View {
        AngularGradient(
            colors: colors + [colors.first ?? .clear],
            center: center,
            angle: .degrees(rotation)
        )
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
