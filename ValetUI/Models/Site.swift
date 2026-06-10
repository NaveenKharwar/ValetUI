import Foundation

struct Site: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let name: String
    let path: String
    let tld: String
    let isSecured: Bool
    let isParked: Bool

    var url: String {
        let scheme = isSecured ? "https" : "http"
        return "\(scheme)://\(name).\(tld)"
    }

    var pathURL: URL {
        URL(fileURLWithPath: path)
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        tld: String = "test",
        isSecured: Bool = false,
        isParked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.tld = tld
        self.isSecured = isSecured
        self.isParked = isParked
    }
}
