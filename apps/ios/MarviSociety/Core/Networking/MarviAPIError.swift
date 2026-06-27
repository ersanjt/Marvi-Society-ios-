import Foundation

enum MarviAPIError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case unauthorized
    case invalidResponse
    case cancelled
    case emailConfirmationRequired
    case server(message: String)
    case decoding(Error)
    case network(Error)

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
