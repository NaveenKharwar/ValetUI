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
            let knownNames = ["nginx", "dnsmasq", "php", "php-fpm"] +
                KnownService.allCases.map(\.brewServiceName)

            let isKnown = knownNames.contains(where: { name.hasPrefix($0) })
            guard isKnown else { continue }

            let displayName = resolveDisplayName(name)
            services.append(ServiceStatus(
                name: name,
                displayName: displayName,
                isRunning: isRunning,
                brewServiceName: name
            ))
        }

        return services
    }

    private static func resolveDisplayName(_ name: String) -> String {
        if name == "nginx" { return "Nginx" }
        if name == "dnsmasq" { return "DNSMasq" }
        if name.hasPrefix("php") { return "PHP-FPM (\(name))" }
        return name.capitalized
    }
}
