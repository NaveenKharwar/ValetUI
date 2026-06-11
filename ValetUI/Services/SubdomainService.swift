import Foundation

struct Subdomain: Identifiable, Hashable, Sendable {
    let id: UUID
    let prefix: String       // "fr"
    let siteName: String     // "mysite"
    let tld: String          // "test"
    let isSecured: Bool

    var fullDomain: String { "\(prefix).\(siteName).\(tld)" }
    var url: String { (isSecured ? "https" : "http") + "://\(fullDomain)" }
    /// The name valet commands use: `valet secure fr.mysite`
    var valetSiteName: String { "\(prefix).\(siteName)" }

    init(prefix: String, siteName: String, tld: String, isSecured: Bool) {
        self.id = UUID()
        self.prefix = prefix
        self.siteName = siteName
        self.tld = tld
        self.isSecured = isSecured
    }
}

/// Valet serves `anything.site.test` natively (DnsMasq wildcard + server.php
/// host fallback) — no Nginx config is needed to make a subdomain work.
/// This service only TRACKS which subdomains the user cares about, plus what
/// Valet can't do alone: per-subdomain HTTPS and WordPress URL handling.
actor SubdomainService {
    static let shared = SubdomainService()
    private init() {}

    private let certsDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Certificates")
    private let nginxDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Nginx")

    // MARK: - Registry

    private var registryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ValetUI", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("subdomains.json")
    }

    /// site key "mysite.test" → sorted prefixes
    private func loadRegistry() -> [String: [String]] {
        guard let data = try? Data(contentsOf: registryURL),
              let registry = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return registry
    }

    private func saveRegistry(_ registry: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        try? data.write(to: registryURL)
    }

    // MARK: - List

    func listSubdomains(for site: Site) -> [Subdomain] {
        migrateLegacyConfigs(for: site)

        let siteKey = "\(site.name).\(site.tld)"
        var prefixes = Set(loadRegistry()[siteKey] ?? [])

        // Pick up subdomains secured outside the app (valet secure fr.mysite):
        // their certs live in the Certificates dir
        let certSuffix = ".\(site.name).\(site.tld).crt"
        if let certs = try? FileManager.default.contentsOfDirectory(atPath: certsDir) {
            for cert in certs where cert.hasSuffix(certSuffix) {
                let prefix = String(cert.dropLast(certSuffix.count))
                if !prefix.isEmpty && !prefix.contains(".") {
                    prefixes.insert(prefix)
                }
            }
        }

        return prefixes.sorted().map { prefix in
            Subdomain(
                prefix: prefix,
                siteName: site.name,
                tld: site.tld,
                isSecured: FileManager.default.fileExists(
                    atPath: "\(certsDir)/\(prefix).\(site.name).\(site.tld).crt"
                )
            )
        }
    }

    // MARK: - Add / Remove

    @discardableResult
    func addSubdomain(prefix: String, site: Site) throws -> Subdomain {
        guard let cleanPrefix = Self.cleanPrefix(prefix) else {
            throw SubdomainError.invalidPrefix
        }

        let siteKey = "\(site.name).\(site.tld)"
        var registry = loadRegistry()
        var prefixes = registry[siteKey] ?? []

        guard !prefixes.contains(cleanPrefix) else {
            throw SubdomainError.alreadyExists("\(cleanPrefix).\(siteKey)")
        }

        prefixes.append(cleanPrefix)
        registry[siteKey] = prefixes.sorted()
        saveRegistry(registry)

        return Subdomain(prefix: cleanPrefix, siteName: site.name, tld: site.tld, isSecured: false)
    }

    func removeSubdomain(_ subdomain: Subdomain) {
        let siteKey = "\(subdomain.siteName).\(subdomain.tld)"
        var registry = loadRegistry()
        registry[siteKey] = (registry[siteKey] ?? []).filter { $0 != subdomain.prefix }
        if registry[siteKey]?.isEmpty == true {
            registry[siteKey] = nil
        }
        saveRegistry(registry)
    }

    /// Lowercased letters, digits, hyphens. Nil when nothing valid remains.
    static func cleanPrefix(_ raw: String) -> String? {
        let cleaned = raw.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" }
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Legacy migration

    /// Pre-registry versions wrote custom Nginx configs per subdomain. They
    /// duplicate Valet's native wildcard routing and break when the PHP socket
    /// moves — import their prefixes into the registry and delete the files.
    /// Valet-written configs (from `valet secure`) are left untouched.
    private func migrateLegacyConfigs(for site: Site) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: nginxDir) else { return }

        let suffix = ".\(site.name).\(site.tld)"
        let siteKey = "\(site.name).\(site.tld)"
        var registry = loadRegistry()
        var prefixes = Set(registry[siteKey] ?? [])
        var changed = false

        for filename in files where filename.hasSuffix(suffix) && filename != siteKey {
            let prefix = String(filename.dropLast(suffix.count))
            guard !prefix.isEmpty, !prefix.contains(".") else { continue }

            let path = (nginxDir as NSString).appendingPathComponent(filename)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }

            // Our old template pointed fastcgi at the brew php-fpm socket;
            // valet's own configs route through valet.sock / server.php
            let isLegacyValetUIConfig = content.contains("/var/run/php/") && !content.contains("valet.sock")
            if isLegacyValetUIConfig {
                prefixes.insert(prefix)
                try? fm.removeItem(atPath: path)
                changed = true
            }
        }

        if changed {
            registry[siteKey] = prefixes.sorted()
            saveRegistry(registry)
        }
    }
}

enum SubdomainError: LocalizedError {
    case invalidPrefix
    case alreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .invalidPrefix:
            return "Subdomain prefix is invalid. Use letters, numbers, and hyphens only."
        case .alreadyExists(let domain):
            return "Subdomain \(domain) already exists."
        }
    }
}
