import Foundation

enum ValetStatus: String, Sendable {
    case running
    case stopped
    case unknown

    var displayName: String {
        switch self {
        case .running: return "Valet Running"
        case .stopped: return "Valet Stopped"
        case .unknown: return "Valet Unknown"
        }
    }

    var isRunning: Bool { self == .running }
}
