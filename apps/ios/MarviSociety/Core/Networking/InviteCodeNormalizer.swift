import Foundation

enum InviteCodeNormalizer {
    static func normalize(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .uppercased()
    }
}
