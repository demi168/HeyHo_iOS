import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonView: View {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<(ASAuthorizationAppleIDCredential, String), Error>) -> Void

    var body: some View {
        SignInWithAppleButtonViewRepresentable(onRequest: onRequest, onCompletion: onCompletion)
            .frame(height: 50)
            .padding(.horizontal, 40)
    }
}

private struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<(ASAuthorizationAppleIDCredential, String), Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 8
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate {
        let parent: SignInWithAppleButtonViewRepresentable
        var currentNonce: String?

        init(_ parent: SignInWithAppleButtonViewRepresentable) {
            self.parent = parent
        }

        @objc func tapped() {
            let nonce = randomNonce()
            currentNonce = nonce
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            parent.onRequest(request)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension SignInWithAppleButtonViewRepresentable.Coordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}

extension SignInWithAppleButtonViewRepresentable.Coordinator {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            parent.onCompletion(.failure(AppleSignInError.invalidCredential))
            return
        }
        let nonce = currentNonce ?? ""
        parent.onCompletion(.success((credential, nonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        parent.onCompletion(.failure(error))
    }
}
