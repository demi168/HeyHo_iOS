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
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.spXlarge)
            }

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
                        await MainActor.run { errorMessage = String(localized: "Could not retrieve token") }
                        return
                    }
                    // サインイン成功後、RootViewが認証状態とプロフィール完了状態を判定して遷移
                    _ = try await authState.signInWithApple(idToken: idTokenData, rawNonce: nonce)
                case .failure(let error):
                    let msg = (error as NSError).domain == "ASAuthorizationError" && (error as NSError).code == 1001
                        ? String(localized: "Cancelled")
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
