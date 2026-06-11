import Foundation

/// Reads Valet state directly from ~/.config/valet/ — no sudo, no TTY needed.
struct ValetConfigReader {

    static let configDir = "\(NSHomeDirectory())/.config/valet"
    static let configPath = "\(configDir)/config.json"
    static let sitesDir = "\(configDir)/Sites"
    static let certificatesDir = "\(configDir)/Certificates"

    // MARK: - Config

    struct ValetConfig: Decodable {
        let tld: String
        let paths: [String]
        let loopback: String?
        /// Valet 4: "ngrok", "expose", or "cloudflared" — nil when never configured
        let shareTool: String?

        enum CodingKeys: String, CodingKey {
            case tld, paths, loopback
            case shareTool = "share-tool"
        }
    }

    static func readConfig() -> ValetConfig? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else { return nil }
        return try? JSONDecoder().decode(ValetConfig.self, from: data)
    }

    // MARK: - Sites

    /// Linked sites — symlinks in ~/.config/valet/Sites/
    static func linkedSites(tld: String) -> [Site] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: sitesDir) else { return [] }

        return entries.compactMap { name -> Site? in
            let fullPath = "\(sitesDir)/\(name)"
            guard let resolved = try? fm.destinationOfSymbolicLink(atPath: fullPath) else { return nil }
            let isSecured = hasCertificate(name: name, tld: tld)
            let isolated = isolatedPHPVersion(name: name, tld: tld)
            return Site(name: name, path: resolved, tld: tld, isSecured: isSecured, isParked: false, isolatedPHP: isolated)
        }.sorted { $0.name < $1.name }
    }

    /// Parked sites — subdirectories of every path in config.json.
    /// Deduplicates nested paths: if /a and /a/b are both in paths, only /a is used.
    static func parkedSites(tld: String, linkedNames: Set<String>) -> [Site] {
        guard let config = readConfig() else { return [] }
        let fm = FileManager.default

        // Remove any path that is a subdirectory of another path in the list
        let sortedPaths = config.paths
            .map { ($0 as NSString).standardizingPath }
            .sorted()  // sort so parents come before children

        var rootPaths: [String] = []
        for path in sortedPaths {
            let isNested = rootPaths.contains { root in
                path.hasPrefix(root + "/")
            }
            if !isNested {
                rootPaths.append(path)
            }
        }

        var seen = Set<String>()
        var sites: [Site] = []

        for parkedPath in rootPaths {
            guard let entries = try? fm.contentsOfDirectory(atPath: parkedPath) else { continue }
            for name in entries {
                guard !linkedNames.contains(name) else { continue }
                guard !seen.contains(name) else { continue }
                guard !name.hasPrefix(".") else { continue }
                let fullPath = "\(parkedPath)/\(name)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let isSecured = hasCertificate(name: name, tld: tld)
                let isolated = isolatedPHPVersion(name: name, tld: tld)
                seen.insert(name)
                sites.append(Site(name: name, path: fullPath, tld: tld, isSecured: isSecured, isParked: true, isolatedPHP: isolated))
            }
        }

        return sites.sorted { $0.name < $1.name }
    }

    static func allSites() -> [Site] {
        let config = readConfig()
        let tld = config?.tld ?? "test"
        let linked = linkedSites(tld: tld)
        let linkedNames = Set(linked.map(\.name))
        let parked = parkedSites(tld: tld, linkedNames: linkedNames)
        return linked + parked
    }

    // MARK: - Certificates

    static func hasCertificate(name: String, tld: String) -> Bool {
        let certPath = "\(certificatesDir)/\(name).\(tld).crt"
        return FileManager.default.fileExists(atPath: certPath)
    }

    // MARK: - PHP isolation

    /// `valet isolate` writes "# ISOLATED_PHP_VERSION=php@8.2" into the site's
    /// Nginx config — returns the brew formula name, or nil if not isolated.
    static func isolatedPHPVersion(name: String, tld: String) -> String? {
        let confPath = "\(configDir)/Nginx/\(name).\(tld)"
        guard let contents = try? String(contentsOfFile: confPath, encoding: .utf8) else { return nil }

        for line in contents.components(separatedBy: .newlines).prefix(5) {
            guard let range = line.range(of: "ISOLATED_PHP_VERSION=") else { continue }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    // MARK: - Is Valet installed

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: configPath)
    }
}
