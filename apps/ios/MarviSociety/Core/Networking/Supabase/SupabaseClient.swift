import Foundation

/// Lightweight Supabase REST + Auth client (no SPM dependency).
actor SupabaseClient {
    private let baseURL: URL
    private let anonKey: String
    private var token: String?
    private var refreshToken: String?
    private var cachedUserID: String?

    init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    var accessToken: String? { token }
    var isAuthenticated: Bool { token != nil }

    func setSession(accessToken: String, refreshToken: String? = nil) {
        token = accessToken
        self.refreshToken = refreshToken
        cachedUserID = currentUserIDFromJWT(accessToken)
        SessionKeychain.save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func clearSession() {
        token = nil
        refreshToken = nil
        cachedUserID = nil
        SessionKeychain.clear()
    }

    func restorePersistedSession() -> Bool {
        guard let stored = SessionKeychain.load() else { return false }
        token = stored.accessToken
        refreshToken = stored.refreshToken
        cachedUserID = currentUserIDFromJWT(stored.accessToken)
        return true
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        var components = URLComponents(
            url: baseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

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
        try applyAuthResponse(from: data)
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        var components = URLComponents(
            url: baseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        try applyAuthResponse(from: data)
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
        try applyAuthResponse(from: data)
    }

    func resetPassword(email: String) async throws {
        let url = baseURL.appending(path: "auth/v1/recover")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "redirect_to": "https://marvisociety.com/portal/login"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func signOut() async throws {
        if let token {
            var request = URLRequest(url: baseURL.appending(path: "auth/v1/logout"))
            request.httpMethod = "POST"
            applyHeaders(&request, authenticated: true)
            _ = try? await URLSession.shared.data(for: request)
            _ = token
        }
        clearSession()
    }

    func refreshSession() async throws {
        guard let refreshToken else {
            throw MarviAPIError.notAuthenticated
        }

        var components = URLComponents(
            url: baseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        try applyAuthResponse(from: data)
    }

    // MARK: - REST

    func select<T: Decodable>(
        table: String,
        query: [URLQueryItem] = [],
        type: T.Type = T.self
    ) async throws -> [T] {
        var components = URLComponents(
            url: baseURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
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

    func rpcVoid(function: String, body: [String: Any]) async throws {
        let url = baseURL.appending(path: "rest/v1/rpc/\(function)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func invokeFunction(name: String, body: [String: Any]) async throws -> Data {
        let url = baseURL.appending(path: "functions/v1/\(name)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    func rpc<T: Decodable>(
        function: String,
        body: [String: Any],
        type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
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
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MarviAPIError.decoding(error)
        }
    }

    func insert(table: String, body: [String: Any]) async throws {
        let url = baseURL.appending(path: "rest/v1/\(table)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func insertReturning<T: Decodable>(
        table: String,
        body: [String: Any],
        type: T.Type = T.self
    ) async throws -> T {
        let url = baseURL.appending(path: "rest/v1/\(table)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        do {
            let rows = try JSONDecoder().decode([T].self, from: data)
            guard let first = rows.first else {
                throw MarviAPIError.invalidResponse
            }
            return first
        } catch let error as MarviAPIError {
            throw error
        } catch {
            throw MarviAPIError.decoding(error)
        }
    }

    func uploadObject(bucket: String, path: String, data: Data, contentType: String) async throws -> String {
        var url = baseURL.appending(path: "storage/v1/object")
        url.append(path: bucket)
        for component in path.split(separator: "/") {
            url.append(path: String(component))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, authenticated: true)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return path
    }

    func currentUserID() async -> String? {
        if let cachedUserID { return cachedUserID }
        if let token, let fromJWT = currentUserIDFromJWT(token) {
            cachedUserID = fromJWT
            return fromJWT
        }
        guard token != nil else { return nil }

        var request = URLRequest(url: baseURL.appending(path: "auth/v1/user"))
        request.httpMethod = "GET"
        applyHeaders(&request, authenticated: true)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String {
                cachedUserID = id
                return id
            }
        } catch {
            return nil
        }

        return nil
    }

    private func currentUserIDFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let padding = 4 - payload.count % 4
        if padding < 4 { payload += String(repeating: "=", count: padding) }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    func patch(table: String, id: UUID, body: [String: Any]) async throws {
        try await patch(
            table: table,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            body: body
        )
    }

    func patch(table: String, query: [URLQueryItem], body: [String: Any]) async throws {
        var components = URLComponents(
            url: baseURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query

        guard let url = components.url else {
            throw MarviAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
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
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MarviAPIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw MarviAPIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String ?? json["error_description"] as? String ?? json["msg"] as? String ?? json["error"] as? String {
                throw MarviAPIError.server(message: message)
            }
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw MarviAPIError.server(message: body)
        }
    }

    private func applyAuthResponse(from data: Data) throws {
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        setSession(accessToken: session.access_token, refreshToken: session.refresh_token)
    }
}

private struct AuthSession: Decodable {
    let access_token: String
    let refresh_token: String?
}
