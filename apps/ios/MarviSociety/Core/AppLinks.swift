import Foundation

enum AppLinks {
    static let website = URL(string: "https://marvisociety.com")!
    static let passwordReset = URL(string: "https://marvisociety.com/auth/reset-password")!
    static let authCallback = URL(string: "https://marvisociety.com/auth/callback")!
    static let oauthCallbackDeepLink = "marvisociety://auth/callback"

    /// HTTPS callback with `client=ios` — Supabase redirects here, then the web page bounces to the app scheme.
    static var iosOAuthCallback: URL {
        var components = URLComponents(url: authCallback, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "client", value: "ios")]
        return components.url!
    }
    static let privacyPolicy = URL(string: "https://marvisociety.com/privacy")!
    static let termsOfService = URL(string: "https://marvisociety.com/terms")!
    static let communityGuidelines = URL(string: "https://marvisociety.com/community-guidelines")!
    static let deleteAccount = URL(string: "https://marvisociety.com/delete-account")!
    static let support = URL(string: "https://marvisociety.com/contact")!
    static let supportEmail = URL(string: "mailto:support@marvisociety.com")!
  static let safetyReportEmail = URL(string: "mailto:support@marvisociety.com?subject=Safety%20report")!
}
