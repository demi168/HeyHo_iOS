import AuthenticationServices
import CryptoKit
import Foundation

enum AppleSignInError: Error {
    case noIdentityToken
    case invalidCredential
}

func randomNonce(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        let rand = Int.random(in: 0..<charset.count)
        result.append(charset[rand])
        remaining -= 1
    }
    return result
}

func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}
