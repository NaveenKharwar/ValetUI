import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class AppViewModel {
    // State
    var valetStatus: ValetStatus = .unknown
    var sites: [Site] = []
    var isRefreshing: Bool = false
    var lastError: String?

    /// First error from any domain — what the menu surfaces
    var anyError: String? {
        lastError ?? phpViewModel.lastError ?? servicesViewModel.lastError
    }

    // Dependency detection
    var isBrewInstalled: Bool = true
    var isValetInstalled: Bool = true
    var isPHPInstalled: Bool = true
    var isWPCLIInstalled: Bool = true
    var isMySQLInstalled: Bool = true

    // Child VMs — own their domain state and actions
    let phpViewModel: PHPViewModel
    let servicesViewModel: ServicesViewModel

    // Auto-refresh
    private var autoRefreshTask: Task<Void, Never>?
    private let shell: ShellCommandService

    init(shell: ShellCommandService = .shared) {
        self.shell = shell
        self.phpViewModel = PHPViewModel(shell: shell)
        self.servicesViewModel = ServicesViewModel(shell: shell)

        phpViewModel.onGlobalRefresh = { [weak self] in await self?.refresh() }
        servicesViewModel.onGlobalRefresh = { [weak self] in await self?.refresh() }

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
        async let phpRefresh: Void = phpViewModel.refresh()
        async let servicesRefresh: Void = servicesViewModel.refresh()

        valetStatus = await statusResult
        _ = await (phpRefresh, servicesRefresh)
    }

    func secureSite(_ site: Site) async {
        guard Site.isValidName(site.name) else {
            showAlert(
                title: "Unsupported site name",
                message: "\"\(site.name)\" contains characters that can't be passed to Terminal safely. Run valet secure manually.",
                style: .warning
            )
            return
        }
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
        guard Site.isValidName(site.name) else {
            showAlert(
                title: "Unsupported site name",
                message: "\"\(site.name)\" contains characters that can't be passed to Terminal safely. Run valet unsecure manually.",
                style: .warning
            )
            return
        }
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

    func isolateSite(_ site: Site, version: PHPVersion) async {
        guard Site.isValidName(site.name) else {
            showAlert(
                title: "Unsupported site name",
                message: "\"\(site.name)\" contains characters that can't be passed to Terminal safely. Run valet isolate manually.",
                style: .warning
            )
            return
        }
        let opened = openTerminal(command: "valet isolate \(version.brewName) --site=\(site.name)")
        if opened {
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        } else {
            showAlert(
                title: "Could not open Terminal",
                message: "Please run this command manually:\n\nvalet isolate \(version.brewName) --site=\(site.name)",
                style: .warning
            )
        }
    }

    func unisolateSite(_ site: Site) async {
        guard Site.isValidName(site.name) else { return }
        let opened = openTerminal(command: "valet unisolate --site=\(site.name)")
        if opened {
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        } else {
            showAlert(
                title: "Could not open Terminal",
                message: "Please run this command manually:\n\nvalet unisolate --site=\(site.name)",
                style: .warning
            )
        }
    }

    func shareSite(_ site: Site) async {
        guard Site.isValidName(site.name) else {
            showAlert(
                title: "Unsupported site name",
                message: "\"\(site.name)\" contains characters that can't be passed to Terminal safely. Run valet share manually.",
                style: .warning
            )
            return
        }

        // Preflight: Valet 4 needs a share tool picked once via `valet share-tool`.
        // Catch the common dead-ends here so the user isn't dumped into a
        // failing Terminal. (nil tool = let valet print its own instructions.)
        switch ValetConfigReader.readConfig()?.shareTool {
        case .some(let tool) where ["ngrok", "cloudflared"].contains(tool):
            let binaryExists = ["/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)"]
                .contains { FileManager.default.fileExists(atPath: $0) }
            if !binaryExists {
                showAlert(
                    title: "\(tool) not installed",
                    message: "Valet is configured to share via \(tool), but it isn't installed.\n\nInstall it with:\n\nbrew install \(tool)",
                    style: .warning
                )
                return
            }

        case .some("expose"):
            guard let exposePath = Self.exposeBinaryPath() else {
                showAlert(
                    title: "expose not installed",
                    message: "Valet is configured to share via expose, but it isn't installed.\n\nInstall it with:\n\ncomposer global require beyondcode/expose",
                    style: .warning
                )
                return
            }
            // expose without a token opens a browser login that frequently
            // fails — check up front and explain the one-time setup instead
            let tokenCheck = await shell.execute(exposePath, arguments: ["token"], timeout: 10)
            if tokenCheck.stdout.lowercased().contains("no authentication token") {
                showAlert(
                    title: "Expose token required",
                    message: "Expose needs a one-time login before sharing:\n\n1. Create a free account at expose.dev\n2. Copy the token from your dashboard\n3. Run in Terminal:  expose token <YOUR-TOKEN>\n\nThen Share will work. Alternatively, switch to a token-free tunnel:\n\nbrew install cloudflared && valet share-tool cloudflared",
                    style: .warning
                )
                return
            }

        default:
            break
        }

        let opened = openTerminal(command: "valet share \(site.name)")
        if !opened {
            showAlert(
                title: "Could not open Terminal",
                message: "Please run this command manually:\n\nvalet share \(site.name)",
                style: .warning
            )
        }
    }

    private static func exposeBinaryPath() -> String? {
        [
            "\(NSHomeDirectory())/.composer/vendor/bin/expose",
            "\(NSHomeDirectory())/.config/composer/vendor/bin/expose",
            "/opt/homebrew/bin/expose",
            "/usr/local/bin/expose",
        ].first { FileManager.default.fileExists(atPath: $0) }
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
        let result = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "list"])
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
        let nginxExists = await shell.fileExists(AppConstants.resolvedNginxPath)
        return nginxExists ? .stopped : .unknown
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
