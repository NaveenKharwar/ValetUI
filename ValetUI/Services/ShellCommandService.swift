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
        timeout: TimeInterval = 30,
        extraEnvironment: [String: String] = [:]
    ) async -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment.merging(extraEnvironment) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Termination handler must be installed before run() so an early exit
        // is never missed; AsyncStream buffers the event until we await it.
        let (exitStream, exitContinuation) = AsyncStream<Void>.makeStream()
        process.terminationHandler = { _ in
            exitContinuation.yield()
            exitContinuation.finish()
        }

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

        // Drain both pipes while the process runs — if output exceeds the 64KB
        // pipe buffer, the child blocks on write and never exits otherwise.
        async let stdoutData = Self.drain(stdoutPipe.fileHandleForReading)
        async let stderrData = Self.drain(stderrPipe.fileHandleForReading)

        for await _ in exitStream {}
        timeoutTask.cancel()

        let stdout = String(data: await stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: await stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ShellCommandResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Read a pipe to EOF without blocking a cooperative-pool thread.
    private static func drain(_ handle: FileHandle) async -> Data {
        var data = Data()
        do {
            for try await byte in handle.bytes {
                data.append(byte)
            }
        } catch {
            // Reading error — return whatever was collected
        }
        return data
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
