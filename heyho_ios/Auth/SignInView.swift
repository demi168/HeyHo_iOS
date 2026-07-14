import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authState: AuthState
    @State private var errorMessage: String?
    @State private var currentLogoIndex = 0
    @State private var logoTimer: Timer?
    private let logoNames = ["SignInLogo01", "SignInLogo02", "SignInLogo03", "SignInLogo04"]
    private let logoInterval: TimeInterval = 1.4

    var body: some View {
        ZStack {
            AppColor.backgroundSignIn
                .ignoresSafeArea()

            signInContent
        }
        .onAppear { errorMessage = nil }
        .errorAlert(
            $errorMessage,
            title: String(localized: "Could not sign in"),
            actionTitle: String(localized: "Close")
        )
    }

    // MARK: - サインイン画面

    private var signInContent: some View {
        VStack(spacing: 0) {
            Spacer()
            logoSection
            Spacer()
            bottomAction
                .padding(.bottom, 56)
        }
    }

    private var logoSection: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Image(logoNames[currentLogoIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.9)
                    .frame(maxWidth: .infinity)
            }
            .aspectRatio(327 / 305, contentMode: .fit)
        }
        .onAppear {
            logoTimer = Timer.scheduledTimer(withTimeInterval: logoInterval, repeats: true) { _ in
                currentLogoIndex = (currentLogoIndex + 1) % logoNames.count
            }
        }
        .onDisappear {
            logoTimer?.invalidate()
            logoTimer = nil
        }
    }

    private var bottomAction: some View {
        VStack(spacing: AppSpacing.spLarge) {
            SignInWithAppleButtonView(
                onRequest: { _ in },
                onCompletion: handleAppleSignInResult
            )

            #if DEBUG
            Button { signInWithDummy() } label: {
                Text("DEBUG: Dummy Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, AppSpacing.spXlarge)
            #endif
        }
    }

    // MARK: - ロジック

    private func handleAppleSignInResult(_ result: Result<(ASAuthorizationAppleIDCredential, String), Error>) {
        errorMessage = nil
        Task {
            do {
                switch result {
                case .success(let (credential, nonce)):
                    guard let idTokenData = credential.identityToken else {
                        AppLogger.auth.error("Apple Sign In: identityTokenが取得できなかった")
                        await MainActor.run { errorMessage = signInErrorMessage }
                        return
                    }
                    // サインイン成功後、RootViewが認証状態とプロフィール完了状態を判定して遷移
                    _ = try await authState.signInWithApple(idToken: idTokenData, rawNonce: nonce)
                case .failure(let error):
                    // シートを閉じる/スワイプで中断した場合はエラー表示せず静かに戻す
                    // （キャンセル時は1001、途中離脱時は1000が返ることがある）
                    guard !error.isAppleSignInCancellation else { return }
                    AppLogger.auth.error("Apple Sign In 失敗: \(error.localizedDescription)")
                    await MainActor.run { errorMessage = signInErrorMessage }
                }
            } catch {
                AppLogger.auth.error("Apple Sign In (Firebase連携) 失敗: \(error.localizedDescription)")
                await MainActor.run { errorMessage = signInErrorMessage }
            }
        }
    }

    private var signInErrorMessage: String {
        String(localized: "Please try signing in with Apple again.")
    }

    #if DEBUG
    private func signInWithDummy() {
        errorMessage = nil
        Task {
            do {
                // サインイン後はRootViewが自動遷移
                try await authState.signInAnonymously()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
    #endif
}
