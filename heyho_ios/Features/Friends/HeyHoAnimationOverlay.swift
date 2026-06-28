import SwiftUI

/// Hey/Hoアニメーションの状態
enum HeyHoAnimationState: Equatable {
    case idle
    /// 自分が送信（右下からフレームイン）
    case sending(message: MessageType, iconColor: IconColorValue, name: String, token: UUID)
    /// 相手から受信（左上からフレームイン）
    case receiving(message: MessageType, iconColor: IconColorValue, name: String, token: UUID)

    // token を比較対象にすることで、同種別の送受信が連続しても毎回「別値」となり
    // onChange(of:) が確実に発火する（messageType だけ比較だと取りこぼしていた）
    static func == (lhs: HeyHoAnimationState, rhs: HeyHoAnimationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.sending(_, _, _, let lt), .sending(_, _, _, let rt)): return lt == rt
        case (.receiving(_, _, _, let lt), .receiving(_, _, _, let rt)): return lt == rt
        default: return false
        }
    }

    var isSending: Bool {
        if case .sending = self { return true }
        return false
    }

    /// 送受信メッセージの種別（idle 時は nil）
    var message: MessageType? {
        switch self {
        case .sending(let m, _, _, _), .receiving(let m, _, _, _): return m
        case .idle: return nil
        }
    }

    var iconColor: IconColorValue? {
        switch self {
        case .sending(_, let c, _, _), .receiving(_, let c, _, _): return c
        case .idle: return nil
        }
    }

    /// 送信先／受信元のユーザー名
    var nameLabel: String? {
        switch self {
        case .sending(_, _, let name, _), .receiving(_, _, let name, _): return name
        case .idle: return nil
        }
    }

    /// メッセージ画像アセット名
    var messageImageName: String? {
        let messageType: MessageType
        switch self {
        case .sending(let m, _, _, _), .receiving(let m, _, _, _): messageType = m
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
    /// アニメーションシーケンス（連続発火時は前回をキャンセルして重複を防ぐ）
    @State private var animationTask: Task<Void, Never>?

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
                // 送信: ラベルを上（HeyBoyは右下）／受信: ラベルを下（HeyBoyは左上）に置き、HeyBoyとの重なりを避ける
                VStack(alignment: .center, spacing: -8) {
                    if isSending, let label = animationState.nameLabel {
                        nameLabelText(label)
                    }

                    if let imageName = animationState.messageImageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: screenW * 0.72)
                    }

                    if !isSending, let label = animationState.nameLabel {
                        nameLabelText(label)
                    }
                }
                .scaleEffect(messageVisible ? 1.0 : 0.75)
                .opacity(messageVisible ? 1.0 : 0.0)
                // 受信はブロックを中央へ（左上のHeyBoyを避ける）、送信は上寄せのまま
                .offset(y: (isSending ? -screenH * 0.12 : 0) + messageOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(animationState != .idle)
        .onChange(of: animationState) {
            guard animationState != .idle, let message = animationState.message else { return }
            // ハプティクスはタップ即時。サウンドはメッセージ表示に同期するため runAnimation 内で再生
            FeedbackService.shared.playHaptic(for: message)
            runAnimation(message: message, isSending: animationState.isSending)
        }
    }

    /// To: / From: のユーザー名ラベル（送信・受信で共通）
    private func nameLabelText(_ label: String) -> some View {
        Text(label)
            .font(.system(size: AppTypography.title, weight: .black))
            .foregroundColor(.white)
            .rotationEffect(.degrees(-15))
    }

    private func runAnimation(message: MessageType, isSending: Bool) {
        // 先に前のシーケンスを止めてから状態を触る（割り込み時の重なりを防ぐ）
        animationTask?.cancel()

        // 初期状態は即時スナップ（進行中の withAnimation と競合させない）
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            bgVisible = false
            heyBoyVisible = false
            messageVisible = false
            messageOffset = 0
        }

        //背景＆HeyBoy表示
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            bgVisible = true
            heyBoyVisible = true
        }

        animationTask = Task { @MainActor in
            //メッセージ表示（+0.21s）＋同時にサウンド再生
            try? await Task.sleep(for: .milliseconds(210))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                messageVisible = true
            }
            FeedbackService.shared.playSound(for: message)

            //メッセージ移動＆背景とHeyBoy非表示（+0.75s）
            try? await Task.sleep(for: .milliseconds(540))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.25)) {
                messageOffset = isSending ? -800 : 800
                messageVisible = false
            }
            withAnimation(.easeIn(duration: 0.2)) {
                heyBoyVisible = false
                bgVisible = false
            }

            //アニメーション完了（+1.5s）
            try? await Task.sleep(for: .milliseconds(750))
            if Task.isCancelled { return }
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
                    animationState = .sending(message: .hey, iconColor: .solid(hex: "FFCC00"), name: "Yurinchy", token: UUID())
                }
                .buttonStyle(.borderedProminent)

                Button("Ho を送る") {
                    animationState = .sending(message: .ho, iconColor: .solid(hex: "FFCC00"), name: "Yurinchy", token: UUID())
                }
                .buttonStyle(.borderedProminent)

                Button("Let's Go を送る") {
                    animationState = .sending(message: .letsGo, iconColor: .gradient(presetId: "sunset"), name: "Yurinchy", token: UUID())
                }
                .buttonStyle(.borderedProminent)

                Button("Hey を受け取る") {
                    animationState = .receiving(message: .hey, iconColor: .solid(hex: "00C0E8"), name: "namename", token: UUID())
                }
                .buttonStyle(.borderedProminent)

                Button("Ho を受け取る") {
                    animationState = .receiving(message: .ho, iconColor: .solid(hex: "00C0E8"), name: "namename", token: UUID())
                }
                .buttonStyle(.borderedProminent)

                Button("Let's Go を受け取る") {
                    animationState = .receiving(message: .letsGo, iconColor: .gradient(presetId: "neon"), name: "namename", token: UUID())
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
