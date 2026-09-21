import Foundation

enum ServiceParser {

    // Parses `brew services list` output
    // Format: Name         Status  User File
    //         nginx        started user /path
    static func parseServices(_ output: String) -> [ServiceStatus] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !$0.lowercased().hasPrefix("name") }

        var services: [ServiceStatus] = []

        for line in lines {
            let parts = line
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard parts.count >= 2 else { continue }

            let name = parts[0]
            let status = parts[1].lowercased()
            let isRunning = status == "started" || status == "running"

            // Only surface known Valet-related services
            let knownNames = ["nginx", "dnsmasq", "php", "php-fpm", "mysql", "mariadb"] +
                KnownService.allCases.map(\.brewServiceName)

            let isKnown = knownNames.contains(where: { name.hasPrefix($0) })
            guard isKnown else { continue }

            // Detect root ownership.
            // started/running → parts: [name, status, user, file]
            // error           → parts: [name, status, exitCode, user, file]
            // none            → parts: [name, status]
            let userField: String?
            if status == "error" || status == "stopped" {
                // parts[2] is exit code (numeric), parts[3] is user
                userField = parts.count >= 4 ? parts[3] : nil
            } else if status == "started" || status == "running" {
                userField = parts.count >= 3 ? parts[2] : nil
            } else {
                userField = nil
            }
            let requiresRoot = userField == "root"

            let displayName = resolveDisplayName(name)
            services.append(ServiceStatus(
                name: name,
                displayName: displayName,
                isRunning: isRunning,
                brewServiceName: name,
                requiresRoot: requiresRoot
            ))
        }

        return services
    }

    private static func resolveDisplayName(_ name: String) -> String {
        if name == "nginx" { return "Nginx" }
        if name == "dnsmasq" { return "DNSMasq" }
        if name.hasPrefix("php") { return "PHP-FPM (\(name))" }
        if name == "mysql" || name.hasPrefix("mysql@") { return "MySQL" }
        if name.hasPrefix("mariadb") { return "MariaDB" }
        return name.capitalized
    }
}
