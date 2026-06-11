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
        await restartNamed(service.brewServiceName)
    }

    func restartNamed(_ name: String) async {
        lastError = nil
        let result = await shell.execute(
            AppConstants.resolvedBrewPath,
            arguments: ["services", "restart", name]
        )
        if result.succeeded {
            await onGlobalRefresh?()
        } else {
            lastError = result.stderr
        }
    }
}
