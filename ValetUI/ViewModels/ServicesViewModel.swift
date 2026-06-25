import Foundation
import Observation

@Observable
@MainActor
final class ServicesViewModel {
    var services: [ServiceStatus] = []
    var lastError: String?

    /// Set by AppViewModel — restarts change Valet status and PHP state too.
    var onGlobalRefresh: (() async -> Void)?

    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }

    func refresh() async {
        let result = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "list"])
        services = ServiceParser.parseServices(result.stdout)
    }

    func restartValet() async {
        // Restart nginx + php via brew services (no sudo needed)
        _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "restart", "nginx"])
        let phpResult = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "list"])
        // Find active php version and restart it
        let phpService = ServiceParser.parseServices(phpResult.stdout)
            .first { $0.name.hasPrefix("php") }
        if let php = phpService {
            _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "restart", php.brewServiceName])
        }
        await onGlobalRefresh?()
    }

    func restart(_ service: ServiceStatus) async {
        await runServiceAction("restart", service.brewServiceName)
    }

    func restartNamed(_ name: String) async {
        await runServiceAction("restart", name)
    }

    func start(_ service: ServiceStatus) async {
        await runServiceAction("start", service.brewServiceName)
    }

    func stop(_ service: ServiceStatus) async {
        await runServiceAction("stop", service.brewServiceName)
    }

    private func runServiceAction(_ action: String, _ name: String) async {
        lastError = nil
        let result = await shell.execute(
            AppConstants.resolvedBrewPath,
            arguments: ["services", action, name]
        )
        if result.succeeded {
            await onGlobalRefresh?()
        } else {
            lastError = result.stderr
        }
    }
}
