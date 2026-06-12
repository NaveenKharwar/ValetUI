import Foundation
import AppKit

struct TerminalOption: Identifiable, Hashable {
    let id: String
    let name: String
    let appPath: String
    let icon: NSImage?

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    static func == (lhs: TerminalOption, rhs: TerminalOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Open terminal at `path`. If `command` is supplied, run it instead of just cd-ing.
    func open(path: String, command: String? = nil) {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        // Build the shell line: cd then command, or just cd
        let shellLine: String
        if let cmd = command {
            shellLine = "cd '\(safePath)' && \(cmd)"
        } else {
            shellLine = "cd '\(safePath)'"
        }
        let safeShellLine = shellLine.replacingOccurrences(of: "\\", with: "\\\\")
                                     .replacingOccurrences(of: "\"", with: "\\\"")

        switch id {
        case "iterm2":
            let script = """
            tell application "iTerm2"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(safeShellLine)"
                    end tell
                end tell
            end tell
            """
            runAppleScript(script)

        case "warp":
            if command == nil {
                // Warp URL scheme only supports path, not arbitrary commands
                let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "warp://action/new_tab?path=\(encoded)") {
                    NSWorkspace.shared.open(url)
                    return
                }
            }
            // Fall through to AppleScript for command mode
            let script = """
            tell application "Warp"
                activate
                do script "\(safeShellLine)"
            end tell
            """
            runAppleScript(script)

        case "ghostty":
            if command == nil {
                let script = """
                do shell script "/Applications/Ghostty.app/Contents/MacOS/ghostty --working-directory='\(safePath)' &"
                """
                runAppleScript(script)
            } else {
                // Ghostty: open with working dir + run command via shell
                let script = """
                do shell script "/Applications/Ghostty.app/Contents/MacOS/ghostty --working-directory='\(safePath)' -e sh -c '\(shellLine.replacingOccurrences(of: "'", with: "'\\''"))' &"
                """
                runAppleScript(script)
            }

        default:
            // Terminal.app, Hyper, and any other app supporting `do script`
            let script = """
            tell application "\(name)"
                activate
                do script "\(safeShellLine)"
            end tell
            """
            runAppleScript(script)
        }
    }

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let err = error {
            print("AppleScript error: \(err)")
        }
    }

    // @MainActor: NSImage isn't Sendable on the Xcode 16 SDK, and every
    // caller is main-actor UI code anyway.
    @MainActor static let all: [TerminalOption] = [
        TerminalOption(
            id: "terminal",
            name: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
        ),
        TerminalOption(
            id: "iterm2",
            name: "iTerm2",
            appPath: "/Applications/iTerm.app",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/iTerm.app")
        ),
        TerminalOption(
            id: "warp",
            name: "Warp",
            appPath: "/Applications/Warp.app",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Warp.app")
        ),
        TerminalOption(
            id: "ghostty",
            name: "Ghostty",
            appPath: "/Applications/Ghostty.app",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Ghostty.app")
        ),
        TerminalOption(
            id: "hyper",
            name: "Hyper",
            appPath: "/Applications/Hyper.app",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Hyper.app")
        ),
    ]

    @MainActor static var installed: [TerminalOption] { all.filter(\.isInstalled) }
}
