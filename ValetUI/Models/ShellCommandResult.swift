import Foundation

struct ShellCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }
    var failed: Bool { !succeeded }

    static let empty = ShellCommandResult(stdout: "", stderr: "", exitCode: 0)

    static func failure(_ message: String) -> ShellCommandResult {
        ShellCommandResult(stdout: "", stderr: message, exitCode: 1)
    }
}
