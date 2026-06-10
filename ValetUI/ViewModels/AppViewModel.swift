import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class AppViewModel {
    // State
    var valetStatus: ValetStatus = .unknown
    var sites: [Site] = []
    var phpVersions: [PHPVersion] = []
    var currentPHP: String = "–"
    var services: [ServiceStatus] = []
    var isRefreshing: Bool = false
    var lastError: String?

    // Dependency detection
    var isBrewInstalled: Bool = true
    var isValetInstalled: Bool = true
    var isPHPInstalled: Bool = true
    var isWPCLIInstalled: Bool = true
    var isMySQLInstalled: Bool = true

    // Child VMs
    let sitesViewModel: SitesViewModel
    let phpViewModel: PHPViewModel
    let servicesViewModel: ServicesViewModel
    let settingsViewModel: SettingsViewModel

    // Auto-refresh
    private var autoRefreshTask: Task<Void, Never>?
    private let shell: ShellCommandService

    init(shell: ShellCommandService = .shared) {
        self.shell = shell
        self.sitesViewModel = SitesViewModel(shell: shell)
        self.phpViewModel = PHPViewModel(shell: shell)
        self.servicesViewModel = ServicesViewModel(shell: shell)
        self.settingsViewModel = SettingsViewModel()

        Task { await checkDependencies() }
        Task { await refresh() }
        setupAutoRefreshIfNeeded()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        // Sites read directly from ~/.config/valet — no subprocess needed
        sites = ValetConfigReader.allSites()

        // Status + PHP + services via shell (no valet CLI needed)
        async let statusResult = fetchValetStatus()
        async let phpResult = fetchPHPInfo()
        async let servicesResult = fetchServices()

        let (status, phpInfo, fetchedServices) = await (statusResult, phpResult, servicesResult)

        valetStatus = status
        currentPHP = phpInfo.currentVersion
        phpVersions = phpInfo.versions
        services = fetchedServices
    }

    func secureSite(_ site: Site) async {
        // valet secure requires sudo + TTY — must run in Terminal via AppleScript
        let opened = openTerminal(command: "valet secure \(site.name)")
        if opened {
            // Refresh after a short delay to pick up new cert
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        } else {
            showAlert(
                title: "Could not open Terminal",
                message: "Please run this command manually:\n\nvalet secure \(site.name)",
                style: .warning
            )
        }
    }

    func unsecureSite(_ site: Site) async {
        let opened = openTerminal(command: "valet unsecure \(site.name)")
        if opened {
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        } else {
            showAlert(
                title: "Could not open Terminal",
                message: "Please run this command manually:\n\nvalet unsecure \(site.name)",
                style: .warning
            )
        }
    }

    // MARK: - Terminal + Alert helpers

    @discardableResult
    func openTerminal(command: String) -> Bool {
        let terminal = AppSettings.shared.resolvedTerminal
            ?? TerminalOption.all.first { $0.id == "terminal" }
        guard let terminal else { return false }
        terminal.open(path: NSHomeDirectory(), command: command)
        return true
    }

    func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func switchPHP(to version: PHPVersion) async {
        // 1. Unlink all currently linked php versions
        let listResult = await shell.executeShell("\(AppConstants.brewPath) list --formula | grep -E '^php(@[0-9.]+)?$'")
        let allVersions = BrewParser.parsePHPVersions(listResult.stdout)
        for v in allVersions where v.brewName != version.brewName {
            _ = await shell.execute(AppConstants.brewPath, arguments: ["unlink", v.brewName])
        }

        // 2. Link the selected version
        let linkResult = await shell.execute(
            AppConstants.brewPath,
            arguments: ["link", "--force", "--overwrite", version.brewName]
        )

        // 3. Restart PHP-FPM service for the new version
        _ = await shell.execute(AppConstants.brewPath, arguments: ["services", "restart", version.brewName])

        if linkResult.succeeded {
            await refresh()
        } else {
            lastError = linkResult.stderr.isEmpty ? "PHP switch failed" : linkResult.stderr
        }
    }

    func restartValet() async {
        // Restart nginx + php via brew services (no sudo needed)
        _ = await shell.execute(AppConstants.brewPath, arguments: ["services", "restart", "nginx"])
        let phpResult = await shell.execute(AppConstants.brewPath, arguments: ["services", "list"])
        // Find active php version and restart it
        let phpService = ServiceParser.parseServices(phpResult.stdout)
            .first { $0.name.hasPrefix("php") }
        if let php = phpService {
            _ = await shell.execute(AppConstants.brewPath, arguments: ["services", "restart", php.brewServiceName])
        }
        await refresh()
    }

    func restartService(_ service: ServiceStatus) async {
        let result = await shell.execute(
            AppConstants.brewPath,
            arguments: ["services", "restart", service.brewServiceName]
        )
        if result.succeeded {
            await refresh()
        } else {
            lastError = result.stderr
        }
    }

    func restartNamedService(_ name: String) async {
        let result = await shell.execute(
            AppConstants.brewPath,
            arguments: ["services", "restart", name]
        )
        if result.succeeded {
            await refresh()
        } else {
            lastError = result.stderr
        }
    }

    func setupAutoRefresh(interval: RefreshInterval) {
        let settings = AppSettings.shared
        settings.refreshInterval = interval
        if settings.autoRefresh {
            startAutoRefresh(interval: interval.rawValue)
        }
    }

    func toggleAutoRefresh(enabled: Bool) {
        AppSettings.shared.autoRefresh = enabled
        if enabled {
            startAutoRefresh(interval: AppSettings.shared.refreshInterval.rawValue)
        } else {
            stopAutoRefresh()
        }
    }

    // MARK: - Private

    func checkDependenciesPublic() async {
        await checkDependencies()
    }

    private func checkDependencies() async {
        isBrewInstalled  = await shell.fileExists(AppConstants.resolvedBrewPath)
        isValetInstalled = ValetConfigReader.isInstalled
        let phpResult    = await shell.execute("/usr/bin/which", arguments: ["php"])
        isPHPInstalled   = phpResult.succeeded && !phpResult.stdout.isEmpty
        isWPCLIInstalled = await shell.fileExists(AppConstants.resolvedWPCLIPath)
        isMySQLInstalled = await shell.fileExists(AppConstants.resolvedMySQLPath)
    }

    /// Determine Valet status from brew services — no sudo, no valet CLI
    private func fetchValetStatus() async -> ValetStatus {
        let result = await shell.execute(AppConstants.brewPath, arguments: ["services", "list"])
        guard result.succeeded else { return .unknown }

        let lines = result.stdout.components(separatedBy: .newlines)
        let nginxRunning = lines.contains { line in
            line.hasPrefix("nginx") && (line.contains("started") || line.contains("running"))
        }
        let phpRunning = lines.contains { line in
            line.hasPrefix("php") && (line.contains("started") || line.contains("running"))
        }

        if nginxRunning || phpRunning {
            return .running
        }

        // Check if nginx is installed at all
        let nginxExists = await shell.fileExists("/opt/homebrew/bin/nginx")
        return nginxExists ? .stopped : .unknown
    }

    private struct PHPInfo {
        let currentVersion: String
        let versions: [PHPVersion]
    }

    private func fetchPHPInfo() async -> PHPInfo {
        async let brewListResult = shell.executeShell("\(AppConstants.brewPath) list --formula | grep -E '^php(@[0-9.]+)?$'")
        async let phpVersionResult = shell.execute("/opt/homebrew/bin/php", arguments: ["-v"])

        let (brewList, phpVer) = await (brewListResult, phpVersionResult)

        var versions = BrewParser.parsePHPVersions(brewList.stdout)
        let currentVersion = ValetParser.parseCurrentPHP(phpVer.stdout) ?? "–"
        BrewParser.resolveCurrentVersion(versions: &versions, currentVersionString: currentVersion)

        return PHPInfo(currentVersion: currentVersion, versions: versions)
    }

    private func fetchServices() async -> [ServiceStatus] {
        let result = await shell.execute(AppConstants.brewPath, arguments: ["services", "list"])
        return ServiceParser.parseServices(result.stdout)
    }

    private func startAutoRefresh(interval: TimeInterval) {
        stopAutoRefresh()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func setupAutoRefreshIfNeeded() {
        let settings = AppSettings.shared
        if settings.autoRefresh {
            startAutoRefresh(interval: settings.refreshInterval.rawValue)
        }
    }
}
