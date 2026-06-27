import SwiftUI

/// 起動スプラッシュ。黒背景に Hey Ho ロゴ（`SignInLogo01`）が
/// ポップ（spring オーバーシュート）＋フェードインで登場 → 約1秒静止 → フェードアウトして本体へ。
/// frame 駆動で拡縮し、ベクター（SVG）のまま crisp に保つ（`HeyBoyLaunchOverlay` と同方針）。
struct SplashView: View {
    /// 認証復元中フラグ。完了するまでフェードアウト（reveal）を待ち、下層グレーのチラ見えを防ぐ
    let isLoading: Bool
    /// フェードアウト完了時に呼ぶ（`RootView` が showSplash=false にして本体を見せる）
    var onFinished: () -> Void = {}

    private let timing = SplashTiming.standard

    /// ロゴ表示幅（frame 駆動。initialScale*target → target でポップ）
    @State private var logoWidth: CGFloat = 0
    /// ロゴのフェードイン（0 → 1）
    @State private var logoOpacity: CGFloat = 0
    /// スプラッシュ全体（黒背景込み）のフェードアウト（1 → 0）。ロゴだけ消すと黒が残るため分離
    @State private var containerOpacity: CGFloat = 1
    /// ポップ開始時刻（reveal 時に残りポップ時間を計算）
    @State private var appearedAt = Date()
    /// reveal の二重起動防止
    @State private var revealing = false
    /// 演出タスク（onDisappear でキャンセル）
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            // ロゴ幅は画面幅基準（Figma 240/≈398 ≒ 0.6。余白を取り 0.62。実機で調整可）
            let targetWidth = geo.size.width * 0.62
            ZStack {
                AppColor.splashBackground
                Image("SignInLogo01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoWidth)
                    .opacity(logoOpacity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .opacity(containerOpacity)
            .onAppear { start(targetWidth: targetWidth) }
            .onChange(of: isLoading) { _, loading in
                if !loading { beginReveal() }
            }
        }
        .ignoresSafeArea()
        .onDisappear { revealTask?.cancel() }
    }

    /// ポップ＋フェードインを開始
    private func start(targetWidth: CGFloat) {
        appearedAt = Date()
        logoWidth = targetWidth * CGFloat(timing.initialScale)
        withAnimation(.spring(response: timing.springResponse,
                              dampingFraction: timing.springDamping)) {
            logoWidth = targetWidth
        }
        withAnimation(.easeIn(duration: timing.fadeInDuration)) {
            logoOpacity = 1
        }
        // 認証復元が既に終わっていれば即 reveal へ
        if !isLoading { beginReveal() }
    }

    /// ポップを見せきってから静止 → フェードアウト → 完了通知
    private func beginReveal() {
        guard !revealing else { return }
        revealing = true
        revealTask = Task { @MainActor in
            // ポップを見せきる（認証が早く終わっても登場演出は完走）
            let remaining = timing.remainingPopIn(elapsed: Date().timeIntervalSince(appearedAt))
            try? await Task.sleep(for: .seconds(remaining))
            // 約1秒静止
            try? await Task.sleep(for: .seconds(timing.holdDuration))
            // 黒背景ごとフェードアウトして下層を見せる
            withAnimation(.easeOut(duration: timing.fadeOutDuration)) {
                containerOpacity = 0
            }
            try? await Task.sleep(for: .seconds(timing.fadeOutDuration))
            onFinished()
        }
    }
}

#if DEBUG
#Preview {
    SplashView(isLoading: true)
}
#endif
