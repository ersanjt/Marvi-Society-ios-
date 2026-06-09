import Foundation

/// Lightweight Supabase REST + Auth client (no SPM dependency).
actor SupabaseClient {
    private let baseURL: URL
    private let anonKey: String
    private var token: String?

    init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    var accessToken: String? { token }
    var isAuthenticated: Bool { token != nil }

    func setSession(accessToken: String) {
        token = accessToken
    }

    func clearSession() {
        token = nil
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        let url = baseURL.appending(path: "auth/v1/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        token = try decodeAccessToken(from: data)
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        var components = URLComponents(url: baseURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        token = try decodeAccessToken(from: data)
    }

    func signUp(email: String, password: String, metadata: [String: String]) async throws {
        let url = baseURL.appending(path: "auth/v1/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "data": metadata
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        if let sessionToken = try? decodeAccessToken(from: data) {
            token = sessionToken
        }
    }

    func signOut() async throws {
        guard let token else { return }
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/logout"))
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        _ = try await URLSession.shared.data(for: request)
        self.token = nil
    }

    // MARK: - REST

    func select<T: Decodable>(
        table: String,
        query: [URLQueryItem] = [],
        type: T.Type = T.self
    ) async throws -> [T] {
        var components = URLComponents(url: baseURL.appending(path: "rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyHeaders(&request, authenticated: true)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw MarviAPIError.decoding(error)
        }
    }

    func rpc<T: Decodable>(
        function: String,
        body: [String: Any],
        type: T.Type = T.self
    ) async throws -> T {
        let url = baseURL.appending(path: "rest/v1/rpc/\(function)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MarviAPIError.decoding(error)
        }
    }

    func patch(table: String, id: UUID, body: [String: Any]) async throws {
        var components = URLComponents(url: baseURL.appending(path: "rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        applyHeaders(&request, authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    // MARK: - Private

    private func applyHeaders(_ request: inout URLRequest, authenticated: Bool) {
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MarviAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String ?? json["error_description"] as? String ?? json["msg"] as? String {
                throw MarviAPIError.server(message: message)
            }
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw MarviAPIError.server(message: body)
        }
    }

    private func decodeAccessToken(from data: Data) throws -> String {
        struct AuthResponse: Decodable {
            let access_token: String
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data).access_token
    }
}
