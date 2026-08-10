import Foundation

enum MarviAPIError: LocalizedError, CustomNSError {
    case notConfigured
    case notAuthenticated
    case unauthorized
    case invalidResponse
    case cancelled
    case emailConfirmationRequired
    case server(message: String)
    case decoding(Error)
    case network(Error)

    static var errorDomain: String { "MarviSociety.MarviAPIError" }

    var errorCode: Int {
        switch self {
        case .notConfigured: 0
        case .notAuthenticated: 1
        case .unauthorized: 2
        case .invalidResponse: 3
        case .cancelled: 4
        case .emailConfirmationRequired: 5
        case .server: 6
        case .decoding: 7
        case .network: 8
        }
    }

    var errorUserInfo: [String: Any] {
        var info: [String: Any] = [:]
        if let description = errorDescription {
            info[NSLocalizedDescriptionKey] = description
        }
        return info
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .notConfigured:
            "Supabase is not configured. Add Secrets.xcconfig with your project URL and anon key."
        case .notAuthenticated:
            "Please sign in to continue."
        case .unauthorized:
            "Your session expired. Please sign in again."
        case .invalidResponse:
            "Unexpected server response."
        case .emailConfirmationRequired:
            "Please confirm your account from the email we just sent, then sign in."
        case .server(let message):
            message
        case .decoding(let error):
            "Could not read server data: \(error.localizedDescription)"
        case .network(let error):
            error.localizedDescription
        }
    }
}
