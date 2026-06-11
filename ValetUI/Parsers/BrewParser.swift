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

        // The unversioned "php" formula gets a "current" placeholder at parse
        // time — substitute the real number from `php -v` so the menu shows
        // "PHP 8.5" instead of "PHP current"
        for i in versions.indices where versions[i].version == "current" {
            versions[i].version = current
        }

        // Mark isCurrent for matching version
        for i in versions.indices {
            versions[i].isCurrent = versions[i].version == current
        }

        // If no version was explicitly matched, ensure no duplicates remain
        let markedCount = versions.filter(\.isCurrent).count
        if markedCount == 0 && !versions.isEmpty {
            // Mark first as current as fallback
            versions[0].isCurrent = true
        }
    }

    /// Resolves the unversioned `php` formula's real version from its Cellar
    /// directory names (e.g. ["8.5.4"] → "8.5"). `php -v` can't be used — it
    /// reports whichever formula is currently linked, not this keg's version.
    static func parseCellarVersion(_ entries: [String]) -> String? {
        let versions = entries.compactMap { entry -> String? in
            let parts = entry.split(separator: ".")
            guard parts.count >= 2, Int(parts[0]) != nil, Int(parts[1]) != nil else { return nil }
            return "\(parts[0]).\(parts[1])"
        }
        return versions.sorted { $0.compare($1, options: .numeric) == .orderedAscending }.last
    }

    private static func isValidPHPVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".")
        return parts.count == 2 &&
               parts.allSatisfy { Int($0) != nil }
    }
}
