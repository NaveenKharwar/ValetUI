import Foundation

enum BrewParser {

    // Parses `brew list --formula` or `brew list | grep php` output
    // Returns installed PHP versions like ["8.1", "8.2", "8.3"]
    static func parsePHPVersions(_ output: String) -> [PHPVersion] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var versions: [PHPVersion] = []

        for line in lines {
            // Match "php", "php@8.1", "php@8.2", "php@8.3", etc.
            if line == "php" {
                // Default PHP (no version suffix) — detect actual version via `php -v`
                versions.append(PHPVersion(version: "current", brewName: "php"))
            } else if line.hasPrefix("php@") {
                let versionStr = String(line.dropFirst(4)) // remove "php@"
                if isValidPHPVersion(versionStr) {
                    versions.append(PHPVersion(version: versionStr, brewName: line))
                }
            }
        }

        return versions.sorted { $0.version > $1.version }
    }

    // Resolves "current" version from `php -v` output and merges with brew list
    static func resolveCurrentVersion(
        versions: inout [PHPVersion],
        currentVersionString: String?
    ) {
        guard let current = currentVersionString else { return }

        // Mark isCurrent for matching version
        for i in versions.indices {
            if versions[i].version == current || versions[i].version == "current" {
                versions[i].isCurrent = true
            } else {
                versions[i].isCurrent = false
            }
        }

        // If no version was explicitly matched, ensure no duplicates remain
        let markedCount = versions.filter(\.isCurrent).count
        if markedCount == 0 && !versions.isEmpty {
            // Mark first as current as fallback
            versions[0].isCurrent = true
        }
    }

    private static func isValidPHPVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".")
        return parts.count == 2 &&
               parts.allSatisfy { Int($0) != nil }
    }
}
