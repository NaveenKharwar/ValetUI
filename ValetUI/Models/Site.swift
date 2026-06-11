import Foundation

struct Site: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let name: String
    let path: String
    let tld: String
    let isSecured: Bool
    let isParked: Bool
    /// Brew formula name (e.g. "php@8.2") when the site is isolated via `valet isolate`
    let isolatedPHP: String?

    var url: String {
        let scheme = isSecured ? "https" : "http"
        return "\(scheme)://\(name).\(tld)"
    }

    var pathURL: URL {
        URL(fileURLWithPath: path)
    }

    /// Safe for use in shell arguments, SQL identifiers, and AppleScript strings.
    /// ASCII letters, digits, hyphen, underscore, dot — no quotes, backticks, or whitespace.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { char in
            char.isASCII && (char.isLetter || char.isNumber || char == "-" || char == "_" || char == ".")
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        tld: String = "test",
        isSecured: Bool = false,
        isParked: Bool = false,
        isolatedPHP: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.tld = tld
        self.isSecured = isSecured
        self.isParked = isParked
        self.isolatedPHP = isolatedPHP
    }
}
