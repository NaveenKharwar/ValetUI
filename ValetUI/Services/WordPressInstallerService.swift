import Foundation

@Observable
@MainActor
final class WordPressInstallerService {

    enum Step: String, CaseIterable {
        case createDirectory   = "Creating directory"
        case downloadWP        = "Downloading WordPress"
        case createDatabase    = "Creating database"
        case createConfig      = "Creating wp-config.php"
        case installWP         = "Installing WordPress"
        case parkSite          = "Adding to Valet paths & configuring URLs"
        case secureSite        = "Enabling HTTPS"
    }

    enum StepState {
        case pending, running, done, failed(String)
    }

    var stepStates: [Step: StepState] = {
        var d: [Step: StepState] = [:]
        Step.allCases.forEach { d[$0] = .pending }
        return d
    }()

    var isRunning = false
    var isComplete = false
    var siteURL: String = ""
    var errorMessage: String?

    func reset() {
        isRunning = false
        isComplete = false
        siteURL = ""
        errorMessage = nil
        Step.allCases.forEach { stepStates[$0] = .pending }
    }

    private let shell = ShellCommandService.shared

    // MARK: - Public

    func install(
        siteName: String,
        baseDir: String,
        dbUser: String,
        dbPass: String,
        adminUser: String,
        adminPassword: String,
        adminEmail: String
    ) async {
        guard !isRunning else { return }

        // Site name reaches SQL identifiers and an AppleScript string — reject
        // anything outside [a-zA-Z0-9-_.] before any step runs.
        guard Site.isValidName(siteName) else {
            errorMessage = "Invalid site name — use only letters, numbers, and hyphens."
            stepStates[.createDirectory] = .failed("Invalid site name")
            return
        }

        isRunning = true
        isComplete = false
        errorMessage = nil
        siteURL = ""
        Step.allCases.forEach { stepStates[$0] = .pending }

        let dbName = siteName.replacingOccurrences(of: "-", with: "_")
        let siteDir = (baseDir as NSString).appendingPathComponent(siteName)
        let tld = ValetConfigReader.readConfig()?.tld ?? "test"
        let fullURL = "https://\(siteName).\(tld)"

        // 1. Create directory
        guard await run(.createDirectory, {
            try FileManager.default.createDirectory(
                atPath: siteDir,
                withIntermediateDirectories: true
            )
        }) else { isRunning = false; return }

        // 2. Download WordPress
        guard await runWPCLI(.downloadWP,
            args: ["core", "download", "--quiet", "--path=\(siteDir)"]
        ) else { cleanup(siteDir: siteDir); isRunning = false; return }

        // 3. Create database — password via MYSQL_PWD, not argv (visible in `ps`)
        guard await runShell(.createDatabase,
            exec: AppConstants.resolvedMySQLPath,
            args: ["-u", dbUser, "-e", "CREATE DATABASE `\(dbName)`;"],
            env: ["MYSQL_PWD": dbPass]
        ) else { cleanup(siteDir: siteDir); isRunning = false; return }

        // 4. Create wp-config.php
        guard await runWPCLI(.createConfig,
            args: [
                "config", "create",
                "--dbname=\(dbName)",
                "--dbuser=\(dbUser)",
                "--dbpass=\(dbPass)",
                "--quiet",
                "--path=\(siteDir)"
            ]
        ) else { cleanup(siteDir: siteDir); isRunning = false; return }

        // 5. Install WordPress
        guard await runWPCLI(.installWP,
            args: [
                "core", "install",
                "--url=\(fullURL)",
                "--title=\(siteName)",
                "--admin_user=\(adminUser)",
                "--admin_password=\(adminPassword)",
                "--admin_email=\(adminEmail)",
                "--skip-email",
                "--quiet",
                "--path=\(siteDir)"
            ]
        ) else { cleanup(siteDir: siteDir); isRunning = false; return }

        // 6. Park + install mu-plugin (WPML local dev fixes)
        // Note: wp-config.php keeps hardcoded WP_HOME — dynamic URL breaks WPML multi-domain
        await run(.parkSite, {
            self.addToValetPaths(baseDir)
            self.installMUPlugin(siteDir: siteDir, siteDomain: "\(siteName).\(tld)")
        })

        // 7. Secure — open Terminal (valet secure needs sudo/TTY)
        set(.secureSite, .running)
        openTerminalForSecure(siteName: siteName)
        set(.secureSite, .done)

        siteURL = fullURL
        isComplete = true
        isRunning = false
    }

    // MARK: - Private helpers

    @discardableResult
    private func run(_ step: Step, _ block: () throws -> Void) async -> Bool {
        set(step, .running)
        do {
            try block()
            set(step, .done)
            return true
        } catch {
            set(step, .failed(error.localizedDescription))
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    private func runWPCLI(_ step: Step, args: [String]) async -> Bool {
        // Call PHP directly so -d memory_limit applies — wp is a Phar,
        // not a shell script, so WP_CLI_PHP_ARGS env var is never read.
        let memoryLimit = AppSettings.shared.wpCLIMemoryLimit
        let phpArgs = ["-d", "memory_limit=\(memoryLimit)", AppConstants.resolvedWPCLIPath] + args
        return await runShell(step, exec: AppConstants.resolvedPHPPath, args: phpArgs)
    }

    @discardableResult
    private func runShell(_ step: Step, exec: String, args: [String], env: [String: String] = [:]) async -> Bool {
        set(step, .running)
        let result = await shell.execute(exec, arguments: args, timeout: 120, extraEnvironment: env)
        if result.succeeded {
            set(step, .done)
            return true
        } else {
            let msg = result.stderr.isEmpty ? "Command failed (exit \(result.exitCode))" : result.stderr
            set(step, .failed(msg))
            errorMessage = msg
            return false
        }
    }

    private func set(_ step: Step, _ state: StepState) {
        stepStates[step] = state
    }

    private func addToValetPaths(_ path: String) {
        let configPath = ValetConfigReader.configPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var paths = config["paths"] as? [String] else { return }

        let normalized = (path as NSString).standardizingPath
        guard !paths.contains(normalized) else { return }
        paths.append(normalized)
        config["paths"] = paths

        guard let newData = try? JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? newData.write(to: URL(fileURLWithPath: configPath))
    }

    private func openTerminalForSecure(siteName: String) {
        let script = "valet secure \(siteName)"
        let source = "tell application \"Terminal\" to do script \"\(script)\""
        let appleScript = NSAppleScript(source: source)
        appleScript?.executeAndReturnError(nil)
    }

    private func installMUPlugin(siteDir: String, siteDomain: String) {
        let muPluginsDir = (siteDir as NSString)
            .appendingPathComponent("wp-content/mu-plugins")
        let pluginPath = (muPluginsDir as NSString)
            .appendingPathComponent("valetui-local-dev.php")

        try? FileManager.default.createDirectory(
            atPath: muPluginsDir,
            withIntermediateDirectories: true
        )

        let content = """
<?php
/**
 * ValetUI local dev mu-plugin.
 * Auto-installed by ValetUI — safe to keep, has no effect on production.
 *
 * Fixes WPML multi-domain language switcher when using dynamic WP_HOME:
 * Injects the default language domain so the language switcher links
 * correctly to the main domain instead of the current subdomain.
 */

// Disable WPML domain validation (local .test domains always fail remote checks)
add_filter( 'wpml_validate_domain', '__return_false' );

// Inject default language into WPML's language_domains on every settings read
add_filter( 'option_icl_sitepress_settings', function( $settings ) {
    if ( ! is_array( $settings ) ) {
        return $settings;
    }
    $main_domain = get_option( 'siteurl' );
    if ( ! $main_domain ) {
        return $settings;
    }
    $main_domain_bare = preg_replace( '#^https?://#', '', rtrim( $main_domain, '/' ) );
    $default_lang = $settings['default_language'] ?? 'en';
    if ( ! isset( $settings['language_domains'] ) ) {
        $settings['language_domains'] = [];
    }
    $settings['language_domains'][ $default_lang ] = $main_domain_bare;
    return $settings;
} );
"""
        try? content.write(toFile: pluginPath, atomically: true, encoding: .utf8)
    }

    private func cleanup(siteDir: String) {
        try? FileManager.default.removeItem(atPath: siteDir)
    }
}
