import Foundation

enum AppConstants {
    static let bundleID = "io.valetui.app"
    static let appName = "ValetUI"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    // Shell tool paths
    static let brewPath = "/opt/homebrew/bin/brew"
    static let brewPathIntel = "/usr/local/bin/brew"
    static var resolvedBrewPath: String {
        FileManager.default.fileExists(atPath: brewPath) ? brewPath : brewPathIntel
    }

    /// "/opt/homebrew" on Apple Silicon, "/usr/local" on Intel
    static var homebrewPrefix: String {
        FileManager.default.fileExists(atPath: brewPath) ? "/opt/homebrew" : "/usr/local"
    }

    static var resolvedPHPPath: String { "\(homebrewPrefix)/bin/php" }
    static var resolvedNginxPath: String { "\(homebrewPrefix)/bin/nginx" }

    // wp-cli: Intel uses /usr/local/bin/wp, ARM uses /opt/homebrew/bin/wp
    static var resolvedWPCLIPath: String {
        let paths = ["/usr/local/bin/wp", "/opt/homebrew/bin/wp"]
        return paths.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin/wp"
    }

    // MySQL: ARM Homebrew or Intel Homebrew
    static var resolvedMySQLPath: String {
        let paths = ["/opt/homebrew/bin/mysql", "/usr/local/bin/mysql"]
        return paths.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/mysql"
    }

    /// Unix socket file for the running MySQL/MariaDB instance.
    /// Needed when PHP is invoked from a GUI app context where `localhost`
    /// doesn't resolve to the socket automatically.
    /// Uses attributesOfItem — FileManager.fileExists returns false for socket files.
    static var resolvedMySQLSocket: String? {
        let candidates = [
            "/tmp/mysql.sock",
            "/opt/homebrew/var/mysql/mysql.sock",
            "/usr/local/var/mysql/mysql.sock",
            "/var/run/mysqld/mysqld.sock",
        ]
        return candidates.first { path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let type = attrs[.type] as? FileAttributeType else { return false }
            return type == .typeSocket
        }
    }

    /// PHP -d args that point mysqli/PDO at the correct Unix socket.
    /// Empty when no socket is found (PHP falls back to its compiled default).
    static var mysqlSocketArgs: [String] {
        guard let socket = resolvedMySQLSocket else { return [] }
        return [
            "-d", "mysqli.default_socket=\(socket)",
            "-d", "pdo_mysql.default_socket=\(socket)",
        ]
    }

    static var valetPath: String {
        let composerBin = "\(NSHomeDirectory())/.composer/vendor/bin/valet"
        if FileManager.default.fileExists(atPath: composerBin) { return composerBin }
        // Fallback: rely on PATH via shell
        return "/usr/bin/env"
    }

    // Log paths
    static var valetLogPath: String {
        "\(NSHomeDirectory())/.config/valet/Log/nginx-error.log"
    }
    static var nginxLogPath: String { "\(homebrewPrefix)/var/log/nginx/error.log" }
    static var phpLogPath: String {
        "\(homebrewPrefix)/var/log/php-fpm.log"
    }

    // Brew install URL for onboarding
    static let brewInstallURL = "https://brew.sh"
    static let valetInstallURL = "https://laravel.com/docs/valet"
}
