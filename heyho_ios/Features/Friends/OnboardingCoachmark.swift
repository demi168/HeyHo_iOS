import SwiftUI

// MARK: - 吹き出し（コーチマーク）本体

/// オンボーディング用の吹き出し。HeyBoy行の左下から尻尾が伸びる黒背景の吹き出し（Figmaデザイン準拠）
struct OnboardingCoachmark: View {
    let step: OnboardingStep

    private var text: LocalizedStringKey {
        switch step {
        case .tapToSend: return "Hey,Tap me."
        case .waitingReply: return "Wait a moment..."
        case .tapAgain: return "Tap again.Let's Go!"
        case .completed: return "That's all.Enjoy!"
        }
    }

    var body: some View {
        // 尻尾は本体の背後に置く（Figma準拠。テキストより手前に出すと文字が欠けて見える）
        ZStack(alignment: .topLeading) {
            BubbleTailShape()
                .fill(AppColor.buttonPrimaryBackground)
                .frame(width: OnboardingCoachmarkMetrics.tailSize, height: OnboardingCoachmarkMetrics.tailSize)
                .offset(y: -OnboardingCoachmarkMetrics.tailOverlap)

            Text(text)
                .font(.system(size: AppTypography.display, weight: .black))
                .foregroundColor(AppColor.textInverse)
                .multilineTextAlignment(.leading)
                // 横は与えられた幅で折り返し、縦はテキスト量に応じて伸びる（Figmaの開発アノテーション準拠）
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.spXlarge)
                .padding(.vertical, AppSpacing.spLarge)
                .background(
                    RoundedRectangle(cornerRadius: AppSize.radiusLarge)
                        .fill(AppColor.buttonPrimaryBackground)
                )
        }
    }
}

/// 吹き出しの尻尾（左上から突き出す三角形）。Figmaのpath `M0 0L52 52H0V0Z` をそのまま再現
private struct BubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// 吹き出し・尻尾の寸法（Figmaデザイン準拠の値を一元管理）
private enum OnboardingCoachmarkMetrics {
    static let tailSize: CGFloat = 52
    /// 尻尾が吹き出し本体の上端からはみ出す高さ
    static let tailOverlap: CGFloat = 17
    /// 登場・切り替えの spring（HeyBoyLaunchOverlay / NewFriendHighlight のポップインと統一）
    static let appearSpringResponse: Double = 0.45
    static let appearSpringDamping: Double = 0.55
}

// MARK: - スポットライト（対象行の位置を伝搬するPreferenceKey）

/// オンボーディング対象行の画面上の位置を、上位のオーバーレイへ伝搬する
struct OnboardingSpotlightPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// このViewをオンボーディングのスポットライト対象としてマークする（対象でない場合は素通し）
    func onboardingSpotlightTarget(_ isTarget: Bool) -> some View {
        anchorPreference(key: OnboardingSpotlightPreferenceKey.self, value: .bounds) { anchor in
            isTarget ? anchor : nil
        }
    }
}

// MARK: - スポットライト（暗転＋くり抜き＋吹き出し）

/// 対象行以外を暗転させ、対象行の位置に合わせて吹き出しを表示するオーバーレイ
struct OnboardingSpotlightOverlay: View {
    let step: OnboardingStep?
    let anchor: Anchor<CGRect>?

    /// 対象行の下端から吹き出し上端までの間隔（Figmaデザイン準拠）
    private let gapBelowTarget: CGFloat = 25
    /// 対象行の左端から吹き出し左端までのインデント（Figmaデザイン準拠）
    private let leadingInset: CGFloat = 37

    var body: some View {
        GeometryReader { proxy in
            if let step, let anchor {
                let targetRect = proxy[anchor]
                let bubbleX = targetRect.minX + leadingInset
                // 暗転部分（くり抜き穴＝対象行の外側全域）の形状。暗転の描画とヒットテストの両方に使う
                let cutoutShape = Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRoundedRect(
                        in: targetRect,
                        cornerSize: CGSize(width: targetRect.height / 2, height: targetRect.height / 2)
                    )
                }
                ZStack(alignment: .topLeading) {
                    cutoutShape
                        .fill(AppColor.overlayScrim, style: FillStyle(eoFill: true))
                        .transition(.opacity)

                    OnboardingCoachmark(step: step)
                        // ステップ切り替え時も毎回ポップインで登場させる（idでViewを差し替える）
                        .id(step)
                        // 画面右端までの残り幅で折り返す（吹き出し自体は内容にフィット）
                        .frame(maxWidth: proxy.size.width - bubbleX - AppSpacing.spXlarge, alignment: .topLeading)
                        .offset(x: bubbleX, y: targetRect.maxY + gapBelowTarget)
                        .transition(.scale(scale: 0.7, anchor: .topLeading).combined(with: .opacity))
                }
                // ヒットテスト領域を暗転と同じ「くり抜き穴の外側」に限定する。
                // これにより穴の内側（対象行）は素通しで下層のFriendRowへタップが届き、
                // 穴の外側（他の友だち行・ADD FRIENDS・マイページアイコン）は下のonTapGestureが吸収して無効化する
                .contentShape(cutoutShape, eoFill: true)
                .onTapGesture {} // くり抜き穴の外側へのタップを吸収し、暗転中のUIを無効化するためのダミーハンドラ（何もしない）
            }
        }
        // スクリムはセーフエリア（ステータスバー・ホームインジケータ帯）まで覆う
        .ignoresSafeArea()
        .animation(
            .spring(response: OnboardingCoachmarkMetrics.appearSpringResponse,
                    dampingFraction: OnboardingCoachmarkMetrics.appearSpringDamping),
            value: step
        )
    }
}
