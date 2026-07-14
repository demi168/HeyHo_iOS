import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum AppleSignInError: Error {
    case noIdentityToken
    case invalidCredential
}

func randomNonce(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError("SecRandomCopyBytes が失敗しました: OSStatus \(errorCode)")
    }
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}

func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

extension Error {
    /// ユーザーがApple Sign Inシートを明示的にキャンセルした、またはシートを閉じて途中離脱した場合に true。
    /// 前者は ASAuthorizationError.canceled (1001)、後者は environment によって .unknown (1000) が返ることがある。
    var isAppleSignInCancellation: Bool {
        let nsError = self as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else { return false }
        return nsError.code == ASAuthorizationError.canceled.rawValue
            || nsError.code == ASAuthorizationError.unknown.rawValue
    }
}

// MARK: - Apple 再認証ヘルパー（アカウント削除時に使用）

final class AppleReauthHelper: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    /// Apple Sign In を async/await で実行し、ASAuthorization を返す
    func perform(nonce: String) async throws -> ASAuthorization {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = []
        request.nonce = sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first ?? ASPresentationAnchor()
    }
}
