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
    static let nginxLogPath = "/opt/homebrew/var/log/nginx/error.log"
    static var phpLogPath: String {
        "/opt/homebrew/var/log/php-fpm.log"
    }

    // Brew install URL for onboarding
    static let brewInstallURL = "https://brew.sh"
    static let valetInstallURL = "https://laravel.com/docs/valet"
}
