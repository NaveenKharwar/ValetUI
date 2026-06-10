import Foundation

/// Detects and patches WordPress wp-config.php URL configuration.
enum WPConfigService {

    // MARK: - Detection

    /// Returns true if the site directory contains a wp-config.php
    static func isWordPressSite(at sitePath: String) -> Bool {
        let configPath = (sitePath as NSString).appendingPathComponent("wp-config.php")
        return FileManager.default.fileExists(atPath: configPath)
    }

    enum URLMode {
        case hardcoded(home: String, siteurl: String)  // has static defines
        case dynamic                                    // already uses $_SERVER
        case notDefined                                 // no WP_HOME define found
    }

    /// Reads wp-config.php and checks whether WP_HOME/WP_SITEURL are hardcoded.
    static func detectURLMode(at sitePath: String) -> URLMode {
        let configPath = (sitePath as NSString).appendingPathComponent("wp-config.php")
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return .notDefined
        }

        // Already dynamic?
        if content.contains("$_SERVER") &&
           content.contains("WP_HOME") {
            return .dynamic
        }

        // Look for hardcoded define('WP_HOME', 'https://...')
        let homeURL = extractDefineValue(from: content, key: "WP_HOME")
        let siteurlURL = extractDefineValue(from: content, key: "WP_SITEURL")

        if let home = homeURL {
            return .hardcoded(home: home, siteurl: siteurlURL ?? home)
        }

        return .notDefined
    }

    /// Returns true if this site needs WP_HOME defined in wp-config.php.
    /// Hardcoded is CORRECT for WPML multi-domain — do not change it.
    /// Only flag when WP_HOME is completely missing (reads from DB, unreliable).
    static func needsDynamicURLFix(at sitePath: String) -> Bool {
        guard isWordPressSite(at: sitePath) else { return false }
        switch detectURLMode(at: sitePath) {
        case .hardcoded:
            // Hardcoded is fine — this is the correct setup for WPML
            return false
        case .notDefined:
            // No WP_HOME at all → WordPress reads from DB → can be unreliable
            return true
        case .dynamic:
            // Dynamic $_SERVER approach — works for non-WPML but breaks WPML multi-domain
            // Don't force a re-fix, leave it as user chose
            return false
        }
    }

    // MARK: - Fix

    enum FixResult {
        case success
        case alreadyDynamic
        case notWordPress
        case failed(String)
    }

    /// Rewrites WP_HOME and WP_SITEURL in wp-config.php to use dynamic $_SERVER['HTTP_HOST'].
    static func applyDynamicURLFix(at sitePath: String) -> FixResult {
        let configPath = (sitePath as NSString).appendingPathComponent("wp-config.php")

        guard FileManager.default.fileExists(atPath: configPath) else {
            return .notWordPress
        }

        guard var content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return .failed("Could not read wp-config.php")
        }

        // Already patched?
        if content.contains("$_SERVER['HTTP_HOST']") && content.contains("WP_HOME") {
            return .alreadyDynamic
        }

        // Detect the main site domain from the existing hardcoded value or wp-config path
        let mainDomain: String
        switch detectURLMode(at: sitePath) {
        case .hardcoded(let home, _): mainDomain = home
        default:
            // Derive from site folder name + valet TLD
            let folderName = (sitePath as NSString).lastPathComponent
            let tld = ValetConfigReader.readConfig()?.tld ?? "test"
            mainDomain = "https://\(folderName).\(tld)"
        }

        let dynamicBlock = """
// ValetUI: Dynamic URL — supports subdomains, tunnels, and multisite
// Falls back to main domain when running via wp-cli (no HTTP_HOST)
if ( isset( $_SERVER['HTTP_HOST'] ) && $_SERVER['HTTP_HOST'] !== '' ) {
    $protocol = ( isset( $_SERVER['HTTPS'] ) && $_SERVER['HTTPS'] !== 'off' ) ? 'https' : 'http';
    define( 'WP_HOME',    $protocol . '://' . $_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', $protocol . '://' . $_SERVER['HTTP_HOST'] );
} else {
    // wp-cli context — use main site domain
    define( 'WP_HOME',    '\(mainDomain)' );
    define( 'WP_SITEURL', '\(mainDomain)' );
}
"""

        // Remove existing WP_HOME / WP_SITEURL define lines (various formats)
        let patterns = [
            #"(?m)^[^\n]*define\s*\(\s*['"]WP_HOME['"]\s*,\s*['"][^'"]*['"]\s*\)\s*;\n?"#,
            #"(?m)^[^\n]*define\s*\(\s*['"]WP_SITEURL['"]\s*,\s*['"][^'"]*['"]\s*\)\s*;\n?"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(content.startIndex..., in: content)
                content = regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
            }
        }

        // Insert dynamic block before the "That's all" marker, or before <?php closing area
        let markers = [
            "/* That's all, stop editing!",
            "/** That's all",
            "/* Stop editing",
            "require_once",
        ]
        var inserted = false
        for marker in markers {
            if let range = content.range(of: marker) {
                content.insert(contentsOf: dynamicBlock + "\n\n", at: range.lowerBound)
                inserted = true
                break
            }
        }

        if !inserted {
            // Fallback: append before closing
            content += "\n" + dynamicBlock + "\n"
        }

        do {
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private static func extractDefineValue(from content: String, key: String) -> String? {
        // Matches: define('KEY', 'value') or define("KEY", "value") with spaces
        let pattern = #"define\s*\(\s*['"]"# + NSRegularExpression.escapedPattern(for: key) + #"['"]\s*,\s*['"]([^'"]+)['"]\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let valueRange = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[valueRange])
    }
}
