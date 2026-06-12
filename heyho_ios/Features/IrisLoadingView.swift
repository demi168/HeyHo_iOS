import SwiftUI

/// アイリスアウト/イン ローディングアニメーション
/// - アイリスアウト: 画面全体を覆う円が縮小して覗き穴になる
/// - HeyBoyが右下からフレームイン → ローディング待機
/// - 完了後 HeyBoyがフレームアウト → アイリスインで閉じる
struct IrisLoadingView: View {
    @Binding var isLoading: Bool

    /// アイリスの穴（HeyBoy表示エリア）の直径
    private let holeSize: CGFloat = 120
    /// HeyBoyアイコンのサイズ
    private let heyBoySize: CGFloat = AppSize.iconLarge

    // MARK: - アニメーション状態

    @State private var irisRadius: CGFloat = 0
    @State private var heyBoyOffset: CGFloat = 200
    @State private var isVisible = false
    /// アイリスアウト完了 → HeyBoyフレームイン可能
    @State private var isIrisOpen = false
    /// 終了アニメーション進行中
    @State private var isDismissing = false

    var body: some View {
        if isVisible {
            GeometryReader { geo in
                let screenHeight = geo.size.height
                let maxRadius = screenHeight / 2

                ZStack {
                    // 暗いオーバーレイ（円形の穴あき）
                    Color.black
                        .reverseMask {
                            Circle()
                                .frame(width: irisRadius * 2, height: irisRadius * 2)
                        }

                    // HeyBoy（円の中央に配置）
                    HeyBoyIconView(
                        bodyColor: AppColor.defaultIconColor,
                        size: heyBoySize,
                        animated: true,
                        showBackground: false
                    )
                    .offset(x: heyBoyOffset, y: heyBoyOffset)
                }
                .ignoresSafeArea()
                .onAppear {
                    startIrisOut(maxRadius: maxRadius)
                }
            }
        }
    }

    // MARK: - アニメーションシーケンス

    /// フェーズ1: アイリスアウト（大→小に縮小）
    private func startIrisOut(maxRadius: CGFloat) {
        // 初期状態: 円が画面全体を覆う
        irisRadius = maxRadius
        heyBoyOffset = 200

        // 目標サイズまで縮小
        withAnimation(.easeInOut(duration: 0.5)) {
            irisRadius = holeSize / 2
        }

        // 縮小完了後にHeyBoyフレームイン
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            isIrisOpen = true
            startHeyBoyFrameIn()
        }
    }

    /// フェーズ2: HeyBoyフレームイン（右下→中央）
    private func startHeyBoyFrameIn() {
        withAnimation(.easeOut(duration: 0.35)) {
            heyBoyOffset = 0
        }
    }

    /// フェーズ4-5: HeyBoyフレームアウト → アイリスイン
    private func startDismiss() {
        isDismissing = true

        // HeyBoyフレームアウト（中央→右下）
        withAnimation(.easeIn(duration: 0.3)) {
            heyBoyOffset = 200
        }

        // フレームアウト完了後にアイリスイン
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 0.4)) {
                irisRadius = 0
            }

            // アイリスイン完了後に非表示
            try? await Task.sleep(for: .milliseconds(450))
            isVisible = false
            isDismissing = false
            isIrisOpen = false
        }
    }

}

// MARK: - isLoading の変化を監視する modifier 版

extension IrisLoadingView {
    /// onChange を使って isLoading の変化を処理
    fileprivate func withLoadingObserver() -> some View {
        self.onChange(of: isLoading) { oldValue, newValue in
            if newValue && !isVisible {
                // ローディング開始
                isVisible = true
            } else if !newValue && isVisible && !isDismissing {
                // ローディング完了 → 終了アニメーション
                startDismiss()
            }
        }
        .onAppear {
            if isLoading {
                isVisible = true
            }
        }
    }
}

// MARK: - 公開用 ViewModifier

struct IrisLoadingModifier: ViewModifier {
    @Binding var isLoading: Bool

    func body(content: Content) -> some View {
        content.overlay {
            IrisLoadingView(isLoading: $isLoading)
                .withLoadingObserver()
        }
    }
}

extension View {
    /// アイリスローディングオーバーレイを適用
    func irisLoading(isLoading: Binding<Bool>) -> some View {
        modifier(IrisLoadingModifier(isLoading: isLoading))
    }
}

// MARK: - 逆マスク（穴あきオーバーレイ用）

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            Rectangle()
                .overlay(
                    mask()
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        )
    }
}

// MARK: - プレビュー

private struct IrisLoadingPreview: View {
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // 背景コンテンツ（ダミー）
            VStack(spacing: 20) {
                Text("メイン画面")
                    .font(.system(size: AppTypography.title, weight: .bold))
                Button(isLoading ? "ローディング中..." : "ローディング開始") {
                    if !isLoading {
                        isLoading = true
                        // 3秒後に自動完了
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            isLoading = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundPrimary)
        .irisLoading(isLoading: $isLoading)
    }
}

#Preview("アイリスローディング") {
    IrisLoadingPreview()
}
