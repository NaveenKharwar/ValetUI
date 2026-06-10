import Foundation

enum ValetParser {

    // Parses `valet links` output.
    // Format: name  path  url  secured
    // Example line: "myblog  /Users/user/Sites/myblog  http://myblog.test  ~"
    static func parseLinks(_ output: String, tld: String = "test") -> [Site] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Skip header line if present
        let dataLines = lines.filter { line in
            !line.lowercased().hasPrefix("name") &&
            !line.lowercased().hasPrefix("site") &&
            !line.lowercased().hasPrefix("--")
        }

        return dataLines.compactMap { line in
            parseLinkLine(line, tld: tld)
        }
    }

    private static func parseLinkLine(_ line: String, tld: String) -> Site? {
        // Split on 2+ consecutive spaces or tabs
        let components = line
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard components.count >= 2 else { return nil }

        let name = components[0]
        let path = components.count >= 2 ? components[1] : ""
        let isSecured = line.contains("X") || line.contains("✓") || line.contains("secured")

        return Site(
            name: name,
            path: path,
            tld: tld,
            isSecured: isSecured,
            isParked: false
        )
    }

    // Parses `valet parked` output — similar format but all sites in a parked dir
    static func parseParked(_ output: String, tld: String = "test") -> [Site] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let dataLines = lines.filter { line in
            !line.lowercased().hasPrefix("path") &&
            !line.lowercased().hasPrefix("site") &&
            !line.lowercased().hasPrefix("--") &&
            !line.hasPrefix("+")
        }

        return dataLines.compactMap { line -> Site? in
            let parts = line
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard parts.count >= 2 else { return nil }

            let name = parts[0]
            let path = parts[1]
            let isSecured = line.contains("X") || line.contains("✓")

            return Site(
                name: name,
                path: path,
                tld: tld,
                isSecured: isSecured,
                isParked: true
            )
        }
    }

    static func parseStatus(_ output: String) -> ValetStatus {
        let lower = output.lowercased()
        if lower.contains("valet is not running") || lower.contains("stopped") {
            return .stopped
        }
        if lower.contains("nginx") && lower.contains("running") {
            return .running
        }
        if lower.contains("php") && lower.contains("running") {
            return .running
        }
        // valet status exits 0 when running
        return .unknown
    }

    static func parseCurrentPHP(_ phpVersionOutput: String) -> String? {
        // `php -v` output: "PHP 8.3.4 (cli) ..."
        let lines = phpVersionOutput.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { return nil }

        let pattern = /PHP (\d+\.\d+)/
        if let match = firstLine.firstMatch(of: pattern) {
            return String(match.1)
        }
        return nil
    }

    static func parseTLD(_ valetTLDOutput: String) -> String {
        let cleaned = valetTLDOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "test" : cleaned
    }
}
