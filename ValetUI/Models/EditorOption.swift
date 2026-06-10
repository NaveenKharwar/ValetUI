import Foundation
import AppKit

struct EditorOption: Identifiable, Hashable {
    let id: String          // bundle ID or unique key
    let name: String
    let appPath: String
    let cliCommand: String? // e.g. "code", "zed", "subl"
    let icon: NSImage?

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    static func == (lhs: EditorOption, rhs: EditorOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Open a path in this editor
    func open(path: String) {
        if let cli = cliCommand, let cliURL = findCLI(cli) {
            let process = Process()
            process.executableURL = cliURL
            process.arguments = [path]
            try? process.run()
        } else {
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: path)],
                withApplicationAt: URL(fileURLWithPath: appPath),
                configuration: .init()
            ) { _, _ in }
        }
    }

    private func findCLI(_ name: String) -> URL? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        return candidates.compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    // All known editors — filter by isInstalled at runtime
    static let all: [EditorOption] = [
        EditorOption(
            id: "vscode",
            name: "Visual Studio Code",
            appPath: "/Applications/Visual Studio Code.app",
            cliCommand: "code",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Visual Studio Code.app")
        ),
        EditorOption(
            id: "cursor",
            name: "Cursor",
            appPath: "/Applications/Cursor.app",
            cliCommand: "cursor",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Cursor.app")
        ),
        EditorOption(
            id: "zed",
            name: "Zed",
            appPath: "/Applications/Zed.app",
            cliCommand: "zed",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Zed.app")
        ),
        EditorOption(
            id: "phpstorm",
            name: "PhpStorm",
            appPath: "/Applications/PhpStorm.app",
            cliCommand: nil,
            icon: NSWorkspace.shared.icon(forFile: "/Applications/PhpStorm.app")
        ),
        EditorOption(
            id: "sublime",
            name: "Sublime Text",
            appPath: "/Applications/Sublime Text.app",
            cliCommand: "subl",
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Sublime Text.app")
        ),
        EditorOption(
            id: "nova",
            name: "Nova",
            appPath: "/Applications/Nova.app",
            cliCommand: nil,
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Nova.app")
        ),
        EditorOption(
            id: "xcode",
            name: "Xcode",
            appPath: "/Applications/Xcode.app",
            cliCommand: nil,
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Xcode.app")
        ),
        EditorOption(
            id: "finder",
            name: "Finder (folder only)",
            appPath: "/System/Library/CoreServices/Finder.app",
            cliCommand: nil,
            icon: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
        ),
    ]

    static var installed: [EditorOption] { all.filter(\.isInstalled) }
}
