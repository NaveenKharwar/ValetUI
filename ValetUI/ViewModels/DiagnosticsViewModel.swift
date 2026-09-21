import Foundation
import Observation

enum CheckStatus {
    case ok, warning, error, pending
}

struct DiagnosticCheck: Identifiable {
    let id = UUID()
    let name: String
    var status: CheckStatus
    var message: String
    var detail: String?
}

@Observable
@MainActor
final class DiagnosticsViewModel {
    var checks: [DiagnosticCheck] = []
    var recentErrors: String = ""
    var isRunning = false

    private let shell = ShellCommandService.shared

    func runDiagnostics() async {
        isRunning = true
        checks = []
        recentErrors = ""

        await checkPort(80, label: "Nginx (port 80)", expectedProcess: "nginx")
        await checkPHPSocket()
        await checkPort9000Conflict()
        await checkMySQL()
        await collectRecentErrors()

        isRunning = false
    }

    // MARK: - Individual Checks

    private func checkPort(_ port: Int, label: String, expectedProcess: String) async {
        let result = await shell.execute(
            "/usr/sbin/lsof",
            arguments: ["-iTCP:\(port)", "-sTCP:LISTEN", "-n", "-P"]
        )
        let lines = result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("COMMAND") }

        if lines.isEmpty {
            checks.append(.init(
                name: label, status: .error,
                message: "Nothing listening on port \(port)"
            ))
            return
        }

        let processes = lines.compactMap { $0.components(separatedBy: .whitespaces).first }
        let allExpected = processes.allSatisfy { $0.lowercased().hasPrefix(expectedProcess) }

        if allExpected {
            checks.append(.init(name: label, status: .ok, message: "\(expectedProcess) is listening"))
        } else {
            checks.append(.init(
                name: label, status: .warning,
                message: "Unexpected process on port \(port)",
                detail: processes.joined(separator: ", ")
            ))
        }
    }

    private func checkPHPSocket() async {
        let socketPath = "\(NSHomeDirectory())/.config/valet/valet.sock"
        let fm = FileManager.default

        guard let attrs = try? fm.attributesOfItem(atPath: socketPath) else {
            checks.append(.init(
                name: "PHP-FPM socket", status: .error,
                message: "valet.sock not found",
                detail: socketPath
            ))
            return
        }

        // Resolve symlink target
        let target = (try? fm.destinationOfSymbolicLink(atPath: socketPath)) ?? socketPath
        guard let targetAttrs = try? fm.attributesOfItem(atPath: target),
              let fileType = targetAttrs[.type] as? FileAttributeType,
              fileType == .typeSocket else {
            checks.append(.init(
                name: "PHP-FPM socket", status: .error,
                message: "Socket target is missing or not a socket",
                detail: target
            ))
            return
        }

        // Extract PHP version from socket name (e.g. valet82.sock → 8.2)
        let sockName = URL(fileURLWithPath: target).lastPathComponent
        let version = sockName
            .replacingOccurrences(of: "valet", with: "")
            .replacingOccurrences(of: ".sock", with: "")
        let versionLabel = version.isEmpty ? "default" : version

        checks.append(.init(
            name: "PHP-FPM socket", status: .ok,
            message: "Socket active → php\(versionLabel)",
            detail: target
        ))

        _ = attrs // suppress unused warning
    }

    private func checkPort9000Conflict() async {
        let result = await shell.execute(
            "/usr/sbin/lsof",
            arguments: ["-iTCP:9000", "-sTCP:LISTEN", "-n", "-P"]
        )
        let lines = result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("COMMAND") }

        if lines.count > 1 {
            let procs = lines.compactMap { $0.components(separatedBy: .whitespaces).first }
            checks.append(.init(
                name: "Port 9000 (PHP-FPM)", status: .warning,
                message: "\(lines.count) processes on port 9000 — possible conflict",
                detail: procs.joined(separator: ", ")
            ))
        } else if lines.count == 1 {
            checks.append(.init(
                name: "Port 9000 (PHP-FPM)", status: .ok,
                message: "Single PHP-FPM listener"
            ))
        } else {
            checks.append(.init(
                name: "Port 9000 (PHP-FPM)", status: .ok,
                message: "Not in use (socket mode active)"
            ))
        }
    }

    private func checkMySQL() async {
        // Check socket file first (most reliable)
        let candidates = [
            "/tmp/mysql.sock",
            "/tmp/mysqld.sock",
            "\(AppConstants.homebrewPrefix)/var/mysql/mysql.sock",
        ]
        let socketExists = candidates.contains { path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let type = attrs[.type] as? FileAttributeType else { return false }
            return type == .typeSocket
        }

        if socketExists {
            // Try connecting
            let result = await shell.execute(
                AppConstants.resolvedMySQLPath,
                arguments: ["-u", "root", "-e", "SELECT VERSION();"]
            )
            if result.succeeded {
                let version = result.stdout
                    .components(separatedBy: .newlines)
                    .first { !$0.contains("VERSION") && !$0.isEmpty } ?? "unknown"
                checks.append(.init(
                    name: "MySQL", status: .ok,
                    message: "Running — v\(version.trimmingCharacters(in: .whitespaces))"
                ))
            } else {
                checks.append(.init(
                    name: "MySQL", status: .warning,
                    message: "Socket exists but connection refused",
                    detail: result.stderr.components(separatedBy: .newlines).first
                ))
            }
            return
        }

        // Check for version mismatch in error log
        if let errMsg = mysqlVersionMismatchError() {
            checks.append(.init(
                name: "MySQL", status: .error,
                message: "Version mismatch — data files incompatible",
                detail: errMsg
            ))
            return
        }

        checks.append(.init(
            name: "MySQL", status: .error,
            message: "MySQL not running (socket not found)"
        ))
    }

    private func mysqlVersionMismatchError() -> String? {
        let logDir = "\(AppConstants.homebrewPrefix)/var/mysql"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: logDir) else { return nil }
        guard let errFile = files.first(where: { $0.hasSuffix(".err") }) else { return nil }
        let logPath = "\(logDir)/\(errFile)"
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        return lines.last(where: { $0.contains("Cannot upgrade from") || $0.contains("Invalid MySQL server upgrade") })
    }

    // MARK: - Recent Errors

    private func collectRecentErrors() async {
        var sections: [String] = []

        let logPaths: [(label: String, path: String)] = [
            ("Nginx", AppConstants.valetLogPath),
            ("PHP-FPM", AppConstants.phpLogPath),
        ]

        for entry in logPaths {
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            guard let content = try? String(contentsOfFile: entry.path, encoding: .utf8) else { continue }

            let errorLines = content
                .components(separatedBy: .newlines)
                .filter { line in
                    let l = line.lowercased()
                    return l.contains("error") || l.contains("emerg") || l.contains("crit")
                }
                .suffix(15)
                .joined(separator: "\n")

            if !errorLines.isEmpty {
                sections.append("── \(entry.label) ──\n\(errorLines)")
            }
        }

        recentErrors = sections.joined(separator: "\n\n")
    }
}
