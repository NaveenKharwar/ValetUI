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

        enum CodingKeys: String, CodingKey {
            case tld, paths, loopback
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
            return Site(name: name, path: resolved, tld: tld, isSecured: isSecured, isParked: false)
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
                seen.insert(name)
                sites.append(Site(name: name, path: fullPath, tld: tld, isSecured: isSecured, isParked: true))
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

    // MARK: - Is Valet installed

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: configPath)
    }
}
