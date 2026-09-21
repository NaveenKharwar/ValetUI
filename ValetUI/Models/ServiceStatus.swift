import Foundation

struct ServiceStatus: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let isRunning: Bool
    let brewServiceName: String
    let requiresRoot: Bool

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        isRunning: Bool,
        brewServiceName: String,
        requiresRoot: Bool = false
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.isRunning = isRunning
        self.brewServiceName = brewServiceName
        self.requiresRoot = requiresRoot
    }
}

enum KnownService: String, CaseIterable {
    case nginx
    case dnsmasq
    case phpFpm = "php"
    case mysql

    var brewServiceName: String { rawValue }

    var displayName: String {
        switch self {
        case .nginx: return "Nginx"
        case .dnsmasq: return "DNSMasq"
        case .phpFpm: return "PHP-FPM"
        case .mysql: return "MySQL"
        }
    }
}
