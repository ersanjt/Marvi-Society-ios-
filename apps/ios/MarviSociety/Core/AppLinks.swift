import Foundation

enum AppLinks {
    static let website = URL(string: "https://marvisociety.com")!
    static let passwordReset = URL(string: "https://marvisociety.com/auth/reset-password")!
    static let authCallback = URL(string: "https://marvisociety.com/auth/callback")!
    static let oauthCallbackDeepLink = "marvisociety://auth/callback"

    /// Dedicated HTTPS endpoint that 302-redirects to the app (Supabase allowlist-friendly).
    static let iosOAuthCallback = URL(string: "https://marvisociety.com/auth/ios-callback")!
    static let privacyPolicy = URL(string: "https://marvisociety.com/privacy")!
    static let termsOfService = URL(string: "https://marvisociety.com/terms")!
    static let communityGuidelines = URL(string: "https://marvisociety.com/community-guidelines")!
    static let deleteAccount = URL(string: "https://marvisociety.com/delete-account")!
    static let support = URL(string: "https://marvisociety.com/contact")!
    static let supportEmail = URL(string: "mailto:support@marvisociety.com")!
  static let safetyReportEmail = URL(string: "mailto:support@marvisociety.com?subject=Safety%20report")!
}
