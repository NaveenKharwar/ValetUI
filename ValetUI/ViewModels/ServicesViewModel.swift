import Foundation
import Observation

enum ServiceNotice: Equatable {
    case busy(String)
    case success(String)
    case failure(String)
}

@Observable
@MainActor
final class ServicesViewModel {
    var services: [ServiceStatus] = []
    var lastError: String?
    var notices: [String: ServiceNotice] = [:]

    /// Set by AppViewModel — restarts change Valet status and PHP state too.
    var onGlobalRefresh: (() async -> Void)?
    /// Set by AppViewModel — opens Terminal for privileged commands.
    var onOpenTerminal: ((String) -> Void)?

    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }

    func refresh() async {
        let result = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "list"])
        let parsed = ServiceParser.parseServices(result.stdout)
        services = await resolveActualStatus(parsed)
    }

    // MARK: - Actual status checks

    /// Overrides brew's reported status with real port/socket probes.
    /// brew services list shows "error" for Valet-managed processes even when
    /// they are running fine (because Valet's own process holds the port).
    private func resolveActualStatus(_ list: [ServiceStatus]) async -> [ServiceStatus] {
        var result: [ServiceStatus] = []
        for svc in list {
            let actually = await actuallyRunning(svc)
            guard actually != svc.isRunning else { result.append(svc); continue }
            result.append(ServiceStatus(
                id: svc.id,
                name: svc.name,
                displayName: svc.displayName,
                isRunning: actually,
                brewServiceName: svc.brewServiceName,
                requiresRoot: svc.requiresRoot
            ))
        }
        return result
    }

    private func actuallyRunning(_ svc: ServiceStatus) async -> Bool {
        switch true {
        case svc.name == "nginx":
            return await portHasListener(80, containing: "nginx")
        case svc.name == "dnsmasq":
            // dnsmasq binds UDP:53 — lsof -iTCP misses it; pgrep is reliable
            let r = await shell.execute("/usr/bin/pgrep", arguments: ["-x", "dnsmasq"])
            return r.succeeded && !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case svc.name == "mysql" || svc.name.hasPrefix("mysql@"):
            return AppConstants.resolvedMySQLSocket != nil
        case svc.name.hasPrefix("php"):
            return await phpFpmRunning(for: svc.name)
        default:
            return svc.isRunning
        }
    }

    private func portHasListener(_ port: Int, containing process: String?) async -> Bool {
        let r = await shell.execute(
            "/usr/sbin/lsof",
            arguments: ["-iTCP:\(port)", "-sTCP:LISTEN", "-n", "-P"]
        )
        let lines = r.stdout.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("COMMAND") }
        if let process {
            return lines.contains { $0.lowercased().contains(process) }
        }
        return !lines.isEmpty
    }

    /// Checks whether PHP-FPM for a specific version is running by looking for
    /// its master process config path (e.g. /opt/homebrew/etc/php/8.2/php-fpm.conf).
    /// Socket file checks are unreliable — stale sockets linger after crashes.
    private func phpFpmRunning(for name: String) async -> Bool {
        // Extract version number: php@8.2 → 8.2, php → checked via valet.sock symlink
        let version: String
        if name.contains("@") {
            version = name.components(separatedBy: "@").last ?? ""
        } else {
            // Generic "php" — check what valet.sock currently resolves to
            let sockPath = "\(NSHomeDirectory())/.config/valet/valet.sock"
            let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: sockPath)) ?? ""
            // valet85.sock → 8.5, derive config version
            let sockVersion = target
                .components(separatedBy: "/").last?
                .replacingOccurrences(of: "valet", with: "")
                .replacingOccurrences(of: ".sock", with: "")
                ?? ""
            // Insert dot: "85" → "8.5"
            version = sockVersion.count >= 2
                ? "\(sockVersion.prefix(1)).\(sockVersion.dropFirst())"
                : sockVersion
        }
        guard !version.isEmpty else { return false }
        let confPath = "\(AppConstants.homebrewPrefix)/etc/php/\(version)/php-fpm.conf"
        let r = await shell.execute("/usr/bin/pgrep", arguments: ["-f", confPath])
        return r.succeeded && !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func restartValet() async {
        setNotice(.busy("Restarting…"), for: "_valet")
        _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "restart", "nginx"])
        let phpResult = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "list"])
        let phpService = ServiceParser.parseServices(phpResult.stdout)
            .first { $0.name.hasPrefix("php") }
        if let php = phpService {
            _ = await shell.execute(AppConstants.resolvedBrewPath, arguments: ["services", "restart", php.brewServiceName])
        }
        setNotice(.success("Restarted"), for: "_valet")
        await onGlobalRefresh?()
        clearNotice(for: "_valet", after: 3)
    }

    func restart(_ service: ServiceStatus) async {
        await runServiceAction("restart", service, busyLabel: "Restarting…")
    }

    func restartNamed(_ name: String) async {
        await runServiceAction("restart", nil, name: name, busyLabel: "Restarting…")
    }

    func start(_ service: ServiceStatus) async {
        await runServiceAction("start", service, busyLabel: "Starting…")
    }

    func stop(_ service: ServiceStatus) async {
        await runServiceAction("stop", service, busyLabel: "Stopping…")
    }

    private func runServiceAction(
        _ action: String,
        _ service: ServiceStatus? = nil,
        name overrideName: String? = nil,
        busyLabel: String
    ) async {
        let name = overrideName ?? service?.brewServiceName ?? ""
        lastError = nil
        setNotice(.busy(busyLabel), for: name)

        let result = await shell.execute(
            AppConstants.resolvedBrewPath,
            arguments: ["services", action, name]
        )

        if result.succeeded {
            let label = action == "stop" ? "Stopped" : "Running"
            setNotice(.success(label), for: name)
            await onGlobalRefresh?()
            clearNotice(for: name, after: 3)
        } else {
            // Failed — escalate to sudo via Terminal
            setNotice(.busy("Needs sudo — opening Terminal…"), for: name)
            onOpenTerminal?("sudo \(AppConstants.resolvedBrewPath) services \(action) \(name)")
            Task {
                try? await Task.sleep(for: .seconds(5))
                await onGlobalRefresh?()
            }
            clearNotice(for: name, after: 4)
        }
    }

    private func setNotice(_ notice: ServiceNotice, for key: String) {
        notices[key] = notice
    }

    private func clearNotice(for key: String, after seconds: Int) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            notices.removeValue(forKey: key)
        }
    }
}
