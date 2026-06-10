import Foundation

struct PHPVersion: Identifiable, Hashable, Sendable {
    let id: UUID
    let version: String
    let brewName: String
    var isCurrent: Bool

    var displayName: String { "PHP \(version)" }

    init(id: UUID = UUID(), version: String, brewName: String, isCurrent: Bool = false) {
        self.id = id
        self.version = version
        self.brewName = brewName
        self.isCurrent = isCurrent
    }
}
