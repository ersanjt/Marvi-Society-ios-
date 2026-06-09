import Foundation

enum MarviAPIError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidResponse
    case server(message: String)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase is not configured. Running in local demo mode."
        case .notAuthenticated:
            "Please sign in to continue."
        case .invalidResponse:
            "Unexpected server response."
        case .server(let message):
            message
        case .decoding(let error):
            "Could not read server data: \(error.localizedDescription)"
        case .network(let error):
            error.localizedDescription
        }
    }
}
