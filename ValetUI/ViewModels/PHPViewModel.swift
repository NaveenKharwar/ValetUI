import Foundation
import Observation

@Observable
@MainActor
final class PHPViewModel {
    var versions: [PHPVersion] = []
    var currentVersion: String = "–"
    var lastError: String?

    /// Set by AppViewModel — a PHP switch changes services and Valet status too.
    var onGlobalRefresh: (() async -> Void)?

    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }

    func refresh() async {
        async let brewListResult = shell.executeShell("\(AppConstants.resolvedBrewPath) list --formula | grep -E '^php(@[0-9.]+)?$'")
        async let phpVersionResult = shell.execute(AppConstants.resolvedPHPPath, arguments: ["-v"])

        let (brewList, phpVer) = await (brewListResult, phpVersionResult)

        var parsed = BrewParser.parsePHPVersions(brewList.stdout)
        let current = ValetParser.parseCurrentPHP(phpVer.stdout) ?? "–"

        // Resolve the unversioned "php" formula's real version from its Cellar
        // BEFORE marking current — `php -v` follows the link, so using it here
        // would clone the linked version onto the "php" item and mark both
        if let i = parsed.firstIndex(where: { $0.version == "current" }),
           let cellarVersion = Self.defaultFormulaVersion() {
            parsed[i].version = cellarVersion
        }

        BrewParser.resolveCurrentVersion(versions: &parsed, currentVersionString: current)
        parsed.sort { $0.version.compare($1.version, options: .numeric) == .orderedDescending }

        versions = parsed
        currentVersion = current
    }

    /// Version of the unversioned `php` keg, read from its Cellar directory
    private static func defaultFormulaVersion() -> String? {
        let cellar = "\(AppConstants.homebrewPrefix)/Cellar/php"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: cellar) else { return nil }
        return BrewParser.parseCellarVersion(entries)
    }

    func switchTo(_ version: PHPVersion) async {
        lastError = nil

        // 1. Unlink all other linked php versions
        let listResult = await shell.executeShell("\(AppConstants.resolvedBrewPath) list --formula | grep -E '^php(@[0-9.]+)?$'")
        let allVersions = BrewParser.parsePHPVersions(listResult.stdout)
        for v in allVersions where v.brewName != version.brewName {
            _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["unlink", v.brewName])
        }

        // 2. Link the selected version
        let linkResult = await shell.execute(
            AppConstants.resolvedBrewPath,
            arguments: ["link", "--force", "--overwrite", version.brewName]
        )

        // 3. Restart PHP-FPM service for the new version
        _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "restart", version.brewName])

        if linkResult.succeeded {
            await onGlobalRefresh?()
        } else {
            lastError = linkResult.stderr.isEmpty ? "PHP switch failed" : linkResult.stderr
        }
    }
}
