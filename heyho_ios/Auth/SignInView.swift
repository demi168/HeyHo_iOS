import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authState: AuthState
    @State private var displayName = ""
    @State private var isFirstTimeSetup = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // 背景: Figma #FF2D55
            Color(red: 1.0, green: 0.176, blue: 0.333)
                .ignoresSafeArea()

            if isFirstTimeSetup {
                firstTimeSetupContent
            } else {
                signInContent
            }
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
                    .padding(.horizontal, 24)
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
            .padding(.horizontal, 24)
            #endif
        }
    }

    // MARK: - 初回セットアップ

    private var firstTimeSetupContent: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("表示名を設定")
                .font(.title.bold())
                .foregroundStyle(.white)
            TextField("表示名", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .autocapitalization(.none)
            Button { completeSignIn() } label: {
                Text("はじめる")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
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
                    let (isNew, name) = try await authState.signInWithApple(idToken: idTokenData, rawNonce: nonce)
                    await MainActor.run {
                        if isNew && (name == nil || name?.isEmpty == true) {
                            isFirstTimeSetup = true
                        } else if isNew, let n = name, !n.isEmpty {
                            displayName = n
                            Task { await completeSignInAsync() }
                        }
                    }
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

    private func completeSignIn() {
        Task { await completeSignInAsync() }
    }

    private func completeSignInAsync() async {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try await authState.updateDisplayName(name)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    #if DEBUG
    private func signInWithDummy() {
        errorMessage = nil
        Task {
            do {
                try await authState.signInAnonymously()
                await MainActor.run {
                    isFirstTimeSetup = true
                    displayName = "テストユーザー"
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
    #endif
}
