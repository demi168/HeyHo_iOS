import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authState: AuthState
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppColor.backgroundSignIn
                .ignoresSafeArea()

            signInContent
        }
        .onAppear { errorMessage = nil }
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
            // HeyHo ロゴ
            Image("SignInLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 327, height: 305)

        }
    }

    private var bottomAction: some View {
        VStack(spacing: 16) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.pageHorizontal)
            }

            SignInWithAppleButtonView(
                onRequest: { _ in },
                onCompletion: handleAppleSignInResult
            )

            #if DEBUG
            Button { signInWithDummy() } label: {
                Text("開発用：ダミーサインイン")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, AppSpacing.pageHorizontal)
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
                        await MainActor.run { errorMessage = "トークンを取得できませんでした" }
                        return
                    }
                    // サインイン成功後、RootViewが認証状態とプロフィール完了状態を判定して遷移
                    _ = try await authState.signInWithApple(idToken: idTokenData, rawNonce: nonce)
                case .failure(let error):
                    let msg = (error as NSError).domain == "ASAuthorizationError" && (error as NSError).code == 1001
                        ? "キャンセルされました"
                        : error.localizedDescription
                    await MainActor.run { errorMessage = msg }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
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
