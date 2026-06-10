import Foundation

actor ShellCommandService {
    static let shared = ShellCommandService()

    // Extend PATH to include Homebrew and Composer bin dirs
    private var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/Users/\(NSUserName())/.composer/vendor/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = extraPaths.joined(separator: ":") + ":" + existingPath
        env["HOME"] = NSHomeDirectory()
        return env
    }

    func execute(
        _ executablePath: String,
        arguments: [String] = [],
        timeout: TimeInterval = 30
    ) async -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ShellCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }

        // Timeout handling via a concurrent task
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeout))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ShellCommandResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    // Convenience: run via /bin/sh for piped commands only when truly needed.
    // Arguments are NOT interpolated into the command string here — callers must
    // pass a static command string with no user-controlled content.
    func executeShell(_ staticCommand: String, timeout: TimeInterval = 30) async -> ShellCommandResult {
        await execute("/bin/sh", arguments: ["-c", staticCommand], timeout: timeout)
    }

    func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
