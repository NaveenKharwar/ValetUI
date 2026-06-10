import Foundation

extension String {
    // Sanitize a site name for use as a shell argument.
    // Only alphanumeric and hyphens allowed — anything else is rejected.
    var isValidSiteName: Bool {
        !isEmpty && range(of: "^[a-zA-Z0-9\\-\\.]+$", options: .regularExpression) != nil
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func lines() -> [String] {
        components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
    }
}
