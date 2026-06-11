import Foundation
import AppKit

@Observable
@MainActor
final class SiteDeleterService {

    enum Step: String, CaseIterable {
        case detectDatabase   = "Detecting database"
        case dropDatabase     = "Dropping database"
        case removeNginx      = "Removing Nginx config"
        case removeCerts      = "Removing SSL certificates"
        case removeSymlink    = "Removing Valet link"
        case moveToTrash      = "Moving files to Trash"
        case reloadNginx      = "Reloading Nginx"
    }

    enum StepState {
        case pending, running, done, skipped, failed(String)
    }

    struct DeletionPlan {
        let site: Site
        let dbName: String?          // nil = not detected / no WP install
        let nginxConfigPath: String
        let certPaths: [String]
        let symlinkPath: String?     // only if linked site
    }

    var stepStates: [Step: StepState] = {
        var d: [Step: StepState] = [:]
        Step.allCases.forEach { d[$0] = .pending }
        return d
    }()

    var isRunning = false
    var isComplete = false
    var detectedDBName: String?
    var errorMessage: String?

    private let shell = ShellCommandService.shared

    // MARK: - Build plan (call before showing confirmation)

    func buildPlan(for site: Site) async -> DeletionPlan {
        let tld = ValetConfigReader.readConfig()?.tld ?? "test"

        // Try to detect DB name from wp-config.php
        let wpConfigPath = site.path + "/wp-config.php"
        var dbName: String? = nil
        if FileManager.default.fileExists(atPath: wpConfigPath) {
            let result = await shell.execute(
                AppConstants.resolvedWPCLIPath,
                arguments: ["config", "get", "DB_NAME", "--path=\(site.path)"],
                timeout: 10
            )
            if result.succeeded {
                // stdout may contain PHP deprecation notices mixed in —
                // the actual DB name is the last non-empty line that doesn't look like a warning
                let candidate = result.stdout
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("Deprecated") && !$0.hasPrefix("Warning") && !$0.hasPrefix("Notice") }
                    .last
                dbName = candidate
            }
        }
        // Fallback: hyphen→underscore
        if dbName == nil || dbName!.isEmpty {
            dbName = site.name.replacingOccurrences(of: "-", with: "_")
        }

        let nginxConfigPath = "\(ValetConfigReader.configDir)/Nginx/\(site.name).\(tld)"
        let certsDir = ValetConfigReader.certificatesDir
        let certPaths = [".conf", ".crt", ".csr", ".key"].map {
            "\(certsDir)/\(site.name).\(tld)\($0)"
        }

        let symlinkPath = "\(ValetConfigReader.sitesDir)/\(site.name)"
        let symlinkExists = FileManager.default.fileExists(atPath: symlinkPath)

        return DeletionPlan(
            site: site,
            dbName: dbName,
            nginxConfigPath: nginxConfigPath,
            certPaths: certPaths,
            symlinkPath: symlinkExists ? symlinkPath : nil
        )
    }

    // MARK: - Execute deletion

    func delete(plan: DeletionPlan, dbUser: String, dbPass: String) async {
        guard !isRunning else { return }
        isRunning = true
        isComplete = false
        errorMessage = nil
        Step.allCases.forEach { stepStates[$0] = .pending }

        // 1. Detect database (already done in plan — mark done)
        set(.detectDatabase, .done)

        // 2. Drop database
        // dbName comes from wp-config.php (arbitrary content) — refuse anything
        // that could escape the backtick-quoted SQL identifier.
        if let dbName = plan.dbName, isSafeDBName(dbName) {
            set(.dropDatabase, .running)
            let result = await shell.execute(
                AppConstants.resolvedMySQLPath,
                arguments: ["-u", dbUser, "-e", "DROP DATABASE IF EXISTS `\(dbName)`;"],
                timeout: 15,
                extraEnvironment: ["MYSQL_PWD": dbPass]
            )
            set(.dropDatabase, result.succeeded ? .done : .failed(result.stderr))
        } else if let dbName = plan.dbName {
            set(.dropDatabase, .failed("Unsafe database name \"\(dbName)\" — drop it manually"))
        } else {
            set(.dropDatabase, .skipped)
        }

        // 3. Remove nginx config
        set(.removeNginx, .running)
        removeFile(plan.nginxConfigPath, step: .removeNginx)

        // 4. Remove SSL certs
        set(.removeCerts, .running)
        var certErrors: [String] = []
        for certPath in plan.certPaths {
            do {
                if FileManager.default.fileExists(atPath: certPath) {
                    try FileManager.default.removeItem(atPath: certPath)
                }
            } catch {
                certErrors.append(error.localizedDescription)
            }
        }
        set(.removeCerts, certErrors.isEmpty ? .done : .failed(certErrors.first ?? ""))

        // 5. Remove symlink
        if let symlinkPath = plan.symlinkPath {
            set(.removeSymlink, .running)
            removeFile(symlinkPath, step: .removeSymlink)
        } else {
            set(.removeSymlink, .skipped)
        }

        // 6. Move site folder to Trash
        set(.moveToTrash, .running)
        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(
                at: URL(fileURLWithPath: plan.site.path),
                resultingItemURL: &trashedURL
            )
            set(.moveToTrash, .done)
        } catch {
            set(.moveToTrash, .failed(error.localizedDescription))
            errorMessage = "Could not move to Trash: \(error.localizedDescription)"
        }

        // 7. Reload nginx
        set(.reloadNginx, .running)
        let nginxResult = await shell.execute(
            AppConstants.brewPath,
            arguments: ["services", "restart", "nginx"]
        )
        set(.reloadNginx, nginxResult.succeeded ? .done : .skipped)

        isComplete = true
        isRunning = false
    }

    // MARK: - Helpers

    private func set(_ step: Step, _ state: StepState) {
        stepStates[step] = state
    }

    private func isSafeDBName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { char in
            char.isASCII && (char.isLetter || char.isNumber || char == "_" || char == "-" || char == "$")
        }
    }

    private func removeFile(_ path: String, step: Step) {
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            set(step, .done)
        } catch {
            set(step, .failed(error.localizedDescription))
        }
    }
}
