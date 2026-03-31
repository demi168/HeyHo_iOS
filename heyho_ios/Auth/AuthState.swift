import SwiftUI
import FirebaseAuth
import AuthenticationServices

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserId: String?
    /// プロフィール設定が完了しているか（displayNameが存在するか）
    @Published private(set) var isProfileSetupComplete = false
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
                if let uid = user?.uid {
                    PushService.shared.saveTokenToFirestoreIfNeeded()
                    // プロフィール設定状態を確認
                    let hasProfile = await self?.checkProfileSetup(userId: uid) ?? false
                    self?.isProfileSetupComplete = hasProfile
                } else {
                    self?.isProfileSetupComplete = false
                }
                self?.isLoading = false
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Apple Sign In で取得した credential と nonce で Firebase にサインインする
    func signInWithApple(idToken: Data, rawNonce: String) async throws -> (isNewUser: Bool, displayName: String?) {
        guard let idTokenString = String(data: idToken, encoding: .utf8) else {
            throw NSError(domain: "AuthState", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "IDトークンの変換に失敗しました"
            ])
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: nil
        )
        let result = try await Auth.auth().signIn(with: credential)
        let name: String? = {
            if let fullName = result.user.displayName, !fullName.isEmpty {
                return fullName
            }
            return nil
        }()
        return (result.additionalUserInfo?.isNewUser ?? false, name)
    }

    /// 初回プロフィール設定（createdAt をセットする）
    func createProfile(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
        try await FirestoreService.shared.createUser(
            userId: user.uid,
            displayName: name
        )
    }

    /// 表示名の更新（createdAt は上書きしない）
    func updateDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
        try await FirestoreService.shared.updateDisplayName(
            userId: user.uid,
            displayName: name
        )
    }

    /// Firestoreのユーザードキュメントにプロフィールが設定済みか確認
    private func checkProfileSetup(userId: String) async -> Bool {
        guard let user = try? await FirestoreService.shared.getUser(userId: userId) else {
            return false
        }
        // displayNameが空でなければ設定済みとみなす
        return !user.displayName.isEmpty
    }

    /// プロフィール設定完了をマーク（EditProfileView保存後に呼ぶ）
    func markProfileSetupComplete() {
        isProfileSetupComplete = true
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// アカウントを削除する（Apple トークン revoke + Firebase Auth 削除）
    /// Cloud Function onUserDeleted が Firestore データを自動クリーンアップする
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthState", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ユーザーが見つかりません"])
        }

        let hasAppleProvider = user.providerData.contains { $0.providerID == "apple.com" }

        if hasAppleProvider {
            // Apple 再認証 → トークン revoke
            let nonce = randomNonce()
            let helper = AppleReauthHelper()
            let authorization = try await helper.perform(nonce: nonce)

            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = appleCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8) else {
                throw NSError(domain: "AuthState", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Apple認証情報の取得に失敗しました"])
            }

            // Firebase 再認証
            let oauthCredential = OAuthProvider.appleCredential(
                withIDToken: idToken, rawNonce: nonce, fullName: nil)
            try await user.reauthenticate(with: oauthCredential)

            // Apple トークン revoke
            if let authCodeData = appleCredential.authorizationCode,
               let authCode = String(data: authCodeData, encoding: .utf8) {
                try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
            }
        }

        // Firebase Auth ユーザー削除 → onUserDeleted トリガー発火
        try await user.delete()
    }

    #if DEBUG
    /// 開発用：匿名サインイン
    func signInAnonymously() async throws {
        _ = try await Auth.auth().signInAnonymously()
    }
    #endif
}
