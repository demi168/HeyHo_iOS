import SwiftUI

/// Hey/Hoアニメーションの状態
enum HeyHoAnimationState: Equatable {
    case idle
    /// 自分が送信（右下からフレームイン）
    case sending(message: MessageType, iconColor: IconColorValue, name: String)
    /// 相手から受信（左上からフレームイン）
    case receiving(message: MessageType, iconColor: IconColorValue, name: String)

    static func == (lhs: HeyHoAnimationState, rhs: HeyHoAnimationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.sending(let lm, _, _), .sending(let rm, _, _)): return lm == rm
        case (.receiving(let lm, _, _), .receiving(let rm, _, _)): return lm == rm
        default: return false
        }
    }

    var isSending: Bool {
        if case .sending = self { return true }
        return false
    }

    var iconColor: IconColorValue? {
        switch self {
        case .sending(_, let c, _), .receiving(_, let c, _): return c
        case .idle: return nil
        }
    }

    /// 「To: 〇〇」または「From: 〇〇」のラベル
    var nameLabel: String? {
        switch self {
        case .sending(_, _, let name): return "To: \(name)"
        case .receiving(_, _, let name): return "From: \(name)"
        case .idle: return nil
        }
    }

    /// メッセージ画像アセット名
    var messageImageName: String? {
        let messageType: MessageType
        switch self {
        case .sending(let m, _, _), .receiving(let m, _, _): messageType = m
        case .idle: return nil
        }
        switch messageType {
        case .hey: return "MessageHey"
        case .ho: return "MessageHo"
        case .letsGo: return "MessageLetsGo"
        }
    }
}

/// Hey/Hoの送受信アニメーションオーバーレイ
struct HeyHoAnimationOverlay: View {
    @Binding var animationState: HeyHoAnimationState

    @State private var bgVisible = false
    @State private var heyBoyVisible = false
    @State private var messageVisible = false
    @State private var messageOffset: CGFloat = 0

    private let heyBoyScale: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width
            let screenH = geo.size.height
            let heyBoySize = screenW * heyBoyScale
            let isSending = animationState.isSending

            ZStack {
                // 半透明黒背景
                if animationState != .idle {
                    Color.black
                        .opacity(bgVisible ? 0.8 : 0.0)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }

                if let iconColor = animationState.iconColor {
                    HeyBoyIconView(
                        iconColorValue: iconColor,
                        size: heyBoySize,
                        animated: false,
                        showBackground: false
                    )
                    .rotationEffect(isSending ? .zero : .degrees(180))
                    .offset(
                        x: heyBoyVisible
                            ? (isSending ? screenW * 0.3 : -screenW * 0.3)
                            : (isSending ? screenW * 0.75 : -screenW * 0.75),
                        y: heyBoyVisible
                            ? (isSending ? screenH * 0.1 : -screenH * 0.3)
                            : (isSending ? screenH * 0.25 : -screenH * 0.5)
                    )
                }

                // To: / From: ラベル + メッセージ（左揃え）
                VStack(alignment: .leading, spacing: 0) {
                    if let label = animationState.nameLabel {
                        Text(label)
                            .font(.system(size: AppTypography.heading, weight: .black))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-15))
                    }

                    if let imageName = animationState.messageImageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: screenW * 0.72)
                    }
                }
                .scaleEffect(messageVisible ? 1.0 : 0.75)
                .opacity(messageVisible ? 1.0 : 0.0)
                .offset(y: -screenH * 0.12 + messageOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(animationState != .idle)
        .onChange(of: animationState) { newState in
            if newState != .idle {
                runAnimation(isSending: newState.isSending)
                // サウンド＆ハプティクス
                if case .sending(let m, _, _) = newState {
                    FeedbackService.shared.playFeedback(for: m, isSending: true)
                } else if case .receiving(let m, _, _) = newState {
                    FeedbackService.shared.playFeedback(for: m, isSending: false)
                }
            }
        }
    }

    private func runAnimation(isSending: Bool) {
        bgVisible = false
        heyBoyVisible = false
        messageVisible = false
        messageOffset = 0

        //背景＆HeyBoy表示
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            bgVisible = true
            heyBoyVisible = true
        }
        //メッセージ表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                messageVisible = true
            }
        }
        //メッセージ移動＆背景とHeyBoy非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeIn(duration: 0.25)) {
                messageOffset = isSending ? -800 : 800
                messageVisible = false
            }
            withAnimation(.easeIn(duration: 0.2)) {
                heyBoyVisible = false
                bgVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            animationState = .idle
        }
    }
}

// MARK: - プレビュー

#if DEBUG

struct HeyHoAnimationPreview: View {
    @State private var animationState: HeyHoAnimationState = .idle

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("アニメーションテスト")
                    .foregroundColor(.white)
                    .font(.system(size: AppTypography.heading, weight: .black))

                Button("Hey を送る") {
                    animationState = .sending(message: .hey, iconColor: .solid(hex: "FFCC00"), name: "Yurinchy")
                }
                .buttonStyle(.borderedProminent)

                Button("Ho を送る") {
                    animationState = .sending(message: .ho, iconColor: .solid(hex: "FFCC00"), name: "Yurinchy")
                }
                .buttonStyle(.borderedProminent)

                Button("Let's Go を送る") {
                    animationState = .sending(message: .letsGo, iconColor: .gradient(presetId: "sunset"), name: "Yurinchy")
                }
                .buttonStyle(.borderedProminent)

                Button("Hey を受け取る") {
                    animationState = .receiving(message: .hey, iconColor: .solid(hex: "00C0E8"), name: "namename")
                }
                .buttonStyle(.borderedProminent)

                Button("Ho を受け取る") {
                    animationState = .receiving(message: .ho, iconColor: .solid(hex: "00C0E8"), name: "namename")
                }
                .buttonStyle(.borderedProminent)

                Button("Let's Go を受け取る") {
                    animationState = .receiving(message: .letsGo, iconColor: .gradient(presetId: "neon"), name: "namename")
                }
                .buttonStyle(.borderedProminent)
            }

            HeyHoAnimationOverlay(animationState: $animationState)
        }
    }
}

#Preview("HeyHoAnimation") {
    HeyHoAnimationPreview()
}

#endif
