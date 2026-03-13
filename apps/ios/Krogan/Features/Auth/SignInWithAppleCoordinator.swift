import AuthenticationServices
import UIKit

/// Performs Sign in with Apple using ASAuthorizationController with an explicit
/// presentation context so the auth sheet has a valid window (fixes error 1000 / stuck on simulator).
final class SignInWithAppleCoordinator: NSObject {
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?
    private weak var window: ASPresentationAnchor?

    func performRequest(presentationAnchor: ASPresentationAnchor) async -> Result<ASAuthorization, Error> {
        await withCheckedContinuation { cont in
            self.continuation = cont
            self.window = presentationAnchor

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        }
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: .success(authorization))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(returning: .failure(error))
        continuation = nil
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let w = window { return w }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first!
    }
}
