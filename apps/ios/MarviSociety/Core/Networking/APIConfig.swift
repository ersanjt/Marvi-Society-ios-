import Foundation

enum APIMode: String {
    case local
    case supabase
}

enum APIConfig {
    static var mode: APIMode {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "MARVI_API_MODE") as? String,
              let parsed = APIMode(rawValue: raw.lowercased()) else {
            return .local
        }
        return parsed
    }

    static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "MARVI_SUPABASE_URL") as? String,
              !raw.isEmpty,
              !raw.contains("YOUR_PROJECT"),
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    static var supabaseAnonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "MARVI_SUPABASE_ANON_KEY") as? String,
              !raw.isEmpty,
              !raw.contains("your-anon") else {
            return nil
        }
        return raw
    }

    static var isSupabaseConfigured: Bool {
        mode == .supabase && supabaseURL != nil && supabaseAnonKey != nil
    }

    static func makeAPI() -> any MarviAPI {
        if isSupabaseConfigured, let url = supabaseURL, let key = supabaseAnonKey {
            let client = SupabaseClient(baseURL: url, anonKey: key)
            return SupabaseMarviAPI(client: client)
        }
        return LocalMarviAPI()
    }
}
