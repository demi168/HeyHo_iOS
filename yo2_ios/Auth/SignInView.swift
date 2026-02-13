import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authState: AuthState
    @State private var displayName = ""
    @State private var isFirstTimeSetup = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Yo")
                .font(.system(size: 64, weight: .bold))
            Text("1タップでつながる")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()

            if isFirstTimeSetup {
                TextField("表示名", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .autocapitalization(.none)
            }

            if !isFirstTimeSetup {
                SignInWithAppleButtonView(
                    onRequest: { _ in },
                    onCompletion: handleAppleSignInResult
                )
            }

            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if isFirstTimeSetup {
                Button {
                    completeSignIn()
                } label: {
                    Text("はじめる")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .onAppear {
            errorMessage = nil
        }
    }

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
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
