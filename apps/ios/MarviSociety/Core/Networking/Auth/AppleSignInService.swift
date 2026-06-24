import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class AppleSignInService: NSObject, ObservableObject {
    @Published var isSigningIn = false
    @Published var lastError: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<(idToken: String, nonce: String), Error>?

    func signIn() async throws -> (idToken: String, nonce: String) {
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let nonce = Self.randomNonce()
            currentNonce = nonce

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            continuation?.resume(throwing: MarviAPIError.invalidResponse)
            continuation = nil
            return
        }
        continuation?.resume(returning: (idToken: idToken, nonce: nonce))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let mapped = Self.friendlyMessage(for: error)
        if let mapped {
            lastError = mapped
            continuation?.resume(throwing: MarviAPIError.server(message: mapped))
        } else {
            // User dismissed the Apple sheet — not an app error.
            continuation?.resume(throwing: MarviAPIError.cancelled)
        }
        continuation = nil
    }

    static func friendlyMessage(for error: Error) -> String? {
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else {
            return error.localizedDescription
        }

        switch ASAuthorizationError.Code(rawValue: nsError.code) {
        case .canceled, .none:
            return nil
        case .unknown:
            return "Sign in with Apple is not available on this device build. Use email sign-in instead."
        case .invalidResponse, .notHandled, .failed:
            return "Apple sign-in failed. Use email sign-in or try again later."
        case .notInteractive:
            return "Apple sign-in could not start. Use email sign-in."
        case .matchedExcludedCredential:
            return "Apple sign-in failed. Use email sign-in or try again later."
        case .credentialImport, .credentialExport:
            return "Apple sign-in failed. Use email sign-in or try again later."
        case .preferSignInWithApple:
            return nil
        case .deviceNotConfiguredForPasskeyCreation:
            return "Apple sign-in is not configured on this device. Use email sign-in."
        @unknown default:
            return "Apple sign-in is unavailable. Use email sign-in."
        }
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let window = scenes.flatMap(\.windows).first(where: { $0.isHidden == false && $0.alpha > 0 }) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        return ASPresentationAnchor()
    }
}
