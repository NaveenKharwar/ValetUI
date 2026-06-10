import Foundation

struct Subdomain: Identifiable, Hashable, Sendable {
    let id: UUID
    let prefix: String       // "fr"
    let siteName: String     // "mysite"
    let tld: String          // "test"
    let nginxConfigPath: String
    let isSecured: Bool

    var fullDomain: String { "\(prefix).\(siteName).\(tld)" }
    var url: String { (isSecured ? "https" : "http") + "://\(fullDomain)" }

    init(prefix: String, siteName: String, tld: String, nginxConfigPath: String, isSecured: Bool) {
        self.id = UUID()
        self.prefix = prefix
        self.siteName = siteName
        self.tld = tld
        self.nginxConfigPath = nginxConfigPath
        self.isSecured = isSecured
    }
}

actor SubdomainService {
    static let shared = SubdomainService()
    private init() {}

    private let shell = ShellCommandService.shared
    private let nginxDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Nginx")
    private let certsDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Certificates")

    // MARK: - List

    func listSubdomains(for site: Site) -> [Subdomain] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: nginxDir) else { return [] }

        let suffix = ".\(site.name).\(site.tld)"
        return files
            .filter { $0.hasSuffix(suffix) && $0 != "\(site.name).\(site.tld)" }
            .compactMap { filename -> Subdomain? in
                let prefix = String(filename.dropLast(suffix.count))
                guard !prefix.isEmpty, !prefix.contains(".") else { return nil }
                let configPath = (nginxDir as NSString).appendingPathComponent(filename)
                let certPath = (certsDir as NSString).appendingPathComponent("\(filename).crt")
                let secured = fm.fileExists(atPath: certPath)
                return Subdomain(
                    prefix: prefix,
                    siteName: site.name,
                    tld: site.tld,
                    nginxConfigPath: configPath,
                    isSecured: secured
                )
            }
            .sorted { $0.prefix < $1.prefix }
    }

    // MARK: - Add

    func addSubdomain(prefix: String, site: Site) async throws {
        let cleanPrefix = prefix.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        guard !cleanPrefix.isEmpty else {
            throw SubdomainError.invalidPrefix
        }

        let fullDomain = "\(cleanPrefix).\(site.name).\(site.tld)"
        let configPath = (nginxDir as NSString).appendingPathComponent(fullDomain)

        guard !FileManager.default.fileExists(atPath: configPath) else {
            throw SubdomainError.alreadyExists(fullDomain)
        }

        let phpSocket = detectPHPSocket()
        let config = nginxConfig(
            serverName: fullDomain,
            root: site.path,
            phpSocket: phpSocket
        )

        try config.write(toFile: configPath, atomically: true, encoding: .utf8)
        await reloadNginx()
    }

    // MARK: - Remove

    func removeSubdomain(_ subdomain: Subdomain) async throws {
        try FileManager.default.removeItem(atPath: subdomain.nginxConfigPath)

        // Also remove certs if they exist
        let certBase = (certsDir as NSString).appendingPathComponent(subdomain.fullDomain)
        try? FileManager.default.removeItem(atPath: certBase + ".crt")
        try? FileManager.default.removeItem(atPath: certBase + ".key")
        try? FileManager.default.removeItem(atPath: certBase + ".csr")

        await reloadNginx()
    }

    // MARK: - Reload Nginx

    func reloadNginx() async {
        _ = await shell.execute(
            "/opt/homebrew/bin/brew",
            arguments: ["services", "reload", "nginx"],
            timeout: 15
        )
    }

    // MARK: - Helpers

    func detectPHPSocket() -> String {
        let runDir = "/opt/homebrew/var/run/php"
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: runDir) {
            let socks = files
                .filter { $0.hasPrefix("php") && $0.hasSuffix("-fpm.sock") }
                .sorted()
                .reversed()
            if let best = socks.first {
                return "\(runDir)/\(best)"
            }
        }
        return "/opt/homebrew/var/run/php/php-fpm.sock"
    }

    private func nginxConfig(serverName: String, root: String, phpSocket: String) -> String {
        return """
server {
    listen 80;
    server_name \(serverName);
    root "\(root)";
    index index.php index.html index.htm;

    access_log off;
    error_log /dev/null;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \\.php$ {
        fastcgi_split_path_info ^(.+\\.php)(/.+)$;
        fastcgi_pass unix:\(phpSocket);
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\\.ht {
        deny all;
    }
}
"""
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
