import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct OAuthSessionTokens {
    let accessToken: String
    let refreshToken: String?
}

/// Google (and other Supabase OAuth providers) via ASWebAuthenticationSession — no Google SDK required.
@MainActor
final class GoogleSignInService: NSObject, ObservableObject {
    @Published var isSigningIn = false
    @Published var lastError: String?

    private var continuation: CheckedContinuation<OAuthSessionTokens, Error>?
    private var authSession: ASWebAuthenticationSession?
    private var pkceVerifier: String?
    private var pendingSupabaseURL: URL?
    private var pendingAnonKey: String?

    static let callbackScheme = "marvisociety"
    static var redirectURL: String { AppLinks.iosOAuthCallback.absoluteString }

    func signIn(supabaseURL: URL, anonKey: String) async throws -> OAuthSessionTokens {
        isSigningIn = true
        lastError = nil
        defer {
            isSigningIn = false
            authSession = nil
            pkceVerifier = nil
            pendingSupabaseURL = nil
            pendingAnonKey = nil
        }

        let verifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(from: verifier)
        pkceVerifier = verifier
        pendingSupabaseURL = supabaseURL
        pendingAnonKey = anonKey

        guard var components = URLComponents(
            url: supabaseURL.appending(path: "auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        ) else {
            throw MarviAPIError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: Self.redirectURL),
            URLQueryItem(name: "scopes", value: "email profile"),
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authorizeURL = components.url else {
            throw MarviAPIError.invalidResponse
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: Self.callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.handleAuthCallback(callbackURL: callbackURL, error: error)
                }
            }

            session.presentationContextProvider = self
            self.authSession = session

            if !session.start() {
                self.continuation = nil
                continuation.resume(throwing: MarviAPIError.server(message: "Could not start Google sign-in."))
            }
        }
    }

    private func handleAuthCallback(callbackURL: URL?, error: Error?) {
        guard let continuation else { return }
        self.continuation = nil

        if let error {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                continuation.resume(throwing: MarviAPIError.cancelled)
                return
            }
            let mapped = error.localizedDescription
            lastError = mapped
            continuation.resume(throwing: MarviAPIError.server(message: mapped))
            return
        }

        guard let callbackURL else {
            continuation.resume(throwing: MarviAPIError.invalidResponse)
            return
        }

        Task { @MainActor in
            do {
                let tokens = try await self.resolveTokens(from: callbackURL)
                continuation.resume(returning: tokens)
            } catch {
                self.lastError = error.localizedDescription
                continuation.resume(throwing: error)
            }
        }
    }

    private func resolveTokens(from url: URL) async throws -> OAuthSessionTokens {
        var params = Self.parseQueryItems(url.query)
        if params.isEmpty, let fragment = url.fragment, !fragment.isEmpty {
            params = Self.parseQueryItems(fragment)
        }

        if let errorDescription = params["error_description"] ?? params["error"] {
            throw MarviAPIError.server(message: errorDescription.replacingOccurrences(of: "+", with: " "))
        }

        if let accessToken = params["access_token"], !accessToken.isEmpty {
            return OAuthSessionTokens(
                accessToken: accessToken,
                refreshToken: params["refresh_token"]
            )
        }

        if let code = params["code"], !code.isEmpty {
            guard let supabaseURL = pendingSupabaseURL,
                  let anonKey = pendingAnonKey,
                  let verifier = pkceVerifier else {
                throw MarviAPIError.invalidResponse
            }
            return try await Self.exchangeAuthorizationCode(
                code,
                verifier: verifier,
                supabaseURL: supabaseURL,
                anonKey: anonKey
            )
        }

        throw MarviAPIError.server(
            message: "Google sign-in did not return a session. Deploy /auth/callback on marvisociety.com and add redirect URLs in Supabase."
        )
    }

    static func parseTokens(from url: URL) throws -> OAuthSessionTokens {
        var params = parseQueryItems(url.query)
        if params.isEmpty, let fragment = url.fragment, !fragment.isEmpty {
            params = parseQueryItems(fragment)
        }

        if let errorDescription = params["error_description"] ?? params["error"] {
            throw MarviAPIError.server(message: errorDescription.replacingOccurrences(of: "+", with: " "))
        }

        guard let accessToken = params["access_token"], !accessToken.isEmpty else {
            throw MarviAPIError.server(message: "Google sign-in did not return a session.")
        }

        return OAuthSessionTokens(
            accessToken: accessToken,
            refreshToken: params["refresh_token"]
        )
    }

    private static func exchangeAuthorizationCode(
        _ code: String,
        verifier: String,
        supabaseURL: URL,
        anonKey: String
    ) async throws -> OAuthSessionTokens {
        var components = URLComponents(
            url: supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "auth_code": code,
            "code_verifier": verifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MarviAPIError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                ?? "Google sign-in token exchange failed."
            throw MarviAPIError.server(message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw MarviAPIError.invalidResponse
        }

        return OAuthSessionTokens(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String
        )
    }

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(buffer).base64URLEncodedString()
    }

    private static func codeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func parseQueryItems(_ raw: String?) -> [String: String] {
        guard let raw, !raw.isEmpty else { return [:] }
        let query = raw.hasPrefix("?") ? String(raw.dropFirst()) : raw
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let value = parts[1].removingPercentEncoding ?? parts[1]
            result[key] = value
        }
        return result
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension GoogleSignInService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let window = scenes.flatMap(\.windows).first(where: { !$0.isHidden && $0.alpha > 0 }) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        return ASPresentationAnchor()
    }
}
