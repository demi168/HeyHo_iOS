import SwiftUI
import FirebaseAuth

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserId: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isLoading = false
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
                if user != nil {
                    PushService.shared.saveTokenToFirestoreIfNeeded()
                }
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

    func updateDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
        try await FirestoreService.shared.createOrUpdateUser(
            userId: user.uid,
            displayName: name,
            fcmToken: nil
        )
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
