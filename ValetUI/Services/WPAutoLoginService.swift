import Foundation

enum WPAutoLoginService {

    /// Generates a one-time auto-login URL for the WordPress admin.
    /// Returns `(url, nil)` on success or `(nil, errorMessage)` on failure.
    @MainActor
    static func generateAutoLoginURL(at sitePath: String, siteURL: String) async -> (url: String?, error: String?) {
        let php   = AppConstants.resolvedPHPPath
        let wp    = AppConstants.resolvedWPCLIPath
        let limit = AppSettings.shared.wpCLIMemoryLimit

        let phpBase = ["-d", "memory_limit=\(limit)"] + AppConstants.mysqlSocketArgs

        // 1. Get the first administrator's ID
        let listResult = await ShellCommandService.shared.execute(
            php,
            arguments: phpBase + [wp,
                        "user", "list",
                        "--role=administrator",
                        "--fields=ID",
                        "--format=ids",
                        "--path=\(sitePath)"],
            timeout: 30
        )

        guard listResult.succeeded else {
            let msg = listResult.stderr.isEmpty ? "exit \(listResult.exitCode)" : listResult.stderr
            return (nil, "wp user list failed: \(msg)")
        }
        let userID = listResult.stdout
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
        guard !userID.isEmpty, Int(userID) != nil else {
            return (nil, "No administrator found (stdout: \"\(listResult.stdout)\")")
        }

        // 2. Random 32-char hex token
        let token = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        // 3. Store as a transient (expires in 120 s, deleted after first use)
        let evalResult = await ShellCommandService.shared.execute(
            php,
            arguments: phpBase + [wp,
                        "eval",
                        "set_transient('valetui_login_\(token)',\(userID),120);",
                        "--path=\(sitePath)"],
            timeout: 30
        )
        guard evalResult.succeeded else {
            let msg = evalResult.stderr.isEmpty ? "exit \(evalResult.exitCode)" : evalResult.stderr
            return (nil, "wp eval failed: \(msg)")
        }

        // 4. Ensure the mu-plugin can handle the login request
        ensureAutoLoginMUPlugin(siteDir: sitePath)

        return ("\(siteURL)?valetui_autologin=\(token)", nil)
    }

    // MARK: - mu-plugin

    /// Installs or patches the ValetUI mu-plugin to include the auto-login handler.
    /// Safe to call repeatedly — no-op when the handler is already present.
    static func ensureAutoLoginMUPlugin(siteDir: String) {
        let muDir      = (siteDir as NSString).appendingPathComponent("wp-content/mu-plugins")
        let pluginPath = (muDir as NSString).appendingPathComponent("valetui-local-dev.php")

        if let existing = try? String(contentsOfFile: pluginPath, encoding: .utf8),
           existing.contains("valetui_autologin") {
            return  // handler already present
        }

        try? FileManager.default.createDirectory(
            atPath: muDir, withIntermediateDirectories: true)

        if var existing = try? String(contentsOfFile: pluginPath, encoding: .utf8) {
            existing += "\n\n" + autoLoginPHPBlock
            try? existing.write(toFile: pluginPath, atomically: true, encoding: .utf8)
        } else {
            let content = """
<?php
/**
 * ValetUI local dev mu-plugin.
 * Auto-installed by ValetUI — safe to keep, has no effect on production.
 */

\(autoLoginPHPBlock)
"""
            try? content.write(toFile: pluginPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - PHP block

    static let autoLoginPHPBlock = #"""
// ValetUI: One-click admin login (local dev only — no-op on production)
add_action( 'init', function () {
    $raw   = isset( $_GET['valetui_autologin'] ) ? $_GET['valetui_autologin'] : '';
    $token = preg_replace( '/[^a-f0-9]/', '', $raw );
    if ( ! $token ) {
        return;
    }
    $user_id = get_transient( 'valetui_login_' . $token );
    if ( ! $user_id ) {
        return;
    }
    delete_transient( 'valetui_login_' . $token );
    wp_set_current_user( (int) $user_id );
    wp_set_auth_cookie( (int) $user_id, true );
    wp_redirect( admin_url() );
    exit;
} );
"""#
}
