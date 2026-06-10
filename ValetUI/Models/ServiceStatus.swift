import Foundation

struct ServiceStatus: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let isRunning: Bool
    let brewServiceName: String

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        isRunning: Bool,
        brewServiceName: String
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.isRunning = isRunning
        self.brewServiceName = brewServiceName
    }
}

enum KnownService: String, CaseIterable {
    case nginx
    case dnsmasq
    case phpFpm = "php"

    var brewServiceName: String { rawValue }

    var displayName: String {
        switch self {
        case .nginx: return "Nginx"
        case .dnsmasq: return "DNSMasq"
        case .phpFpm: return "PHP-FPM"
        }
    }
}
