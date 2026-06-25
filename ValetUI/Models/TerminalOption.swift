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

    /// Open terminal at `path`.
    func open(path: String, command: String? = nil) {
        let resolvedAppPath = FileManager.default.fileExists(atPath: appPath)
            ? appPath
            : NSHomeDirectory() + "/Applications/" + URL(fileURLWithPath: appPath).lastPathComponent
        let appURL = URL(fileURLWithPath: resolvedAppPath)

        if command == nil {
            // No command — just open the directory in the terminal
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: path)],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }

        // Has a command — write a temp .command file and open it.
        // This avoids all AppleScript escaping issues and works with any terminal.
        let script = """
        #!/bin/bash
        source ~/.zshrc 2>/dev/null || source ~/.bash_profile 2>/dev/null || true
        cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))'
        \(command!)
        """
        let tmpFile = NSTemporaryDirectory() + "valetui_\(UUID().uuidString).command"
        do {
            try script.write(toFile: tmpFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpFile)
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: tmpFile)],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } catch {
            print("ValetUI: failed to write temp command file: \(error)")
        }

    }

    // Known terminal bundle IDs — discovery looks these up via Spotlight/NSWorkspace.
    // Add a new bundle ID here to support a new terminal automatically.
    static let knownBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "co.zeit.hyper",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.tabby.app",
        "com.SecureCRT.SecureCRT",
        "io.fig.desktop",          // Amazon Q / Fig
        "com.cursor.ide",
    ]

    @MainActor static var all: [TerminalOption] {
        var result: [TerminalOption] = []
        let ws = NSWorkspace.shared

        for bundleID in knownBundleIDs {
            guard let url = ws.urlForApplication(withBundleIdentifier: bundleID) else { continue }
            let path = url.path
            let appName = Bundle(path: path)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle(path: path)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            let icon = ws.icon(forFile: path)
            result.append(TerminalOption(id: bundleID, name: appName, appPath: path, icon: icon))
        }

        return result
    }

    @MainActor static var installed: [TerminalOption] { all.filter(\.isInstalled) }
}
