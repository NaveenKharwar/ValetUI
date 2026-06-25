import Foundation
import Observation
import AppKit

enum RefreshInterval: Double, CaseIterable, Identifiable {
    case fiveSeconds = 5
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .fiveSeconds: return "5 seconds"
        case .fifteenSeconds: return "15 seconds"
        case .thirtySeconds: return "30 seconds"
        case .oneMinute: return "1 minute"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var autoRefresh: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoRefresh) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoRefresh) }
    }

    var refreshInterval: RefreshInterval {
        get {
            let raw = UserDefaults.standard.double(forKey: Keys.refreshInterval)
            return RefreshInterval(rawValue: raw) ?? .thirtySeconds
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.refreshInterval) }
    }

    var defaultEditorID: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultEditorID) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultEditorID) }
    }

    var customEditorPath: String {
        get { UserDefaults.standard.string(forKey: Keys.customEditorPath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.customEditorPath) }
    }

    var defaultTerminalID: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultTerminalID) ?? "com.apple.Terminal" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultTerminalID) }
    }

    var wpCLIMemoryLimit: String {
        get { UserDefaults.standard.string(forKey: Keys.wpCLIMemoryLimit) ?? "512M" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.wpCLIMemoryLimit) }
    }

    // Resolved editor — falls back to first installed
    var resolvedEditor: EditorOption? {
        if defaultEditorID == "custom" {
            let path = customEditorPath
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return EditorOption(
                    id: "custom",
                    name: (path as NSString).lastPathComponent,
                    appPath: path,
                    cliCommand: nil,
                    icon: NSWorkspace.shared.icon(forFile: path)
                )
            }
        }
        return EditorOption.installed.first { $0.id == defaultEditorID }
            ?? EditorOption.installed.first
    }

    var resolvedTerminal: TerminalOption? {
        TerminalOption.installed.first { $0.id == defaultTerminalID }
            ?? TerminalOption.installed.first
    }

    private enum Keys {
        static let autoRefresh = "autoRefresh"
        static let refreshInterval = "refreshInterval"
        static let defaultEditorID = "defaultEditorID"
        static let customEditorPath = "customEditorPath"
        static let defaultTerminalID = "defaultTerminalID"
        static let wpCLIMemoryLimit = "wpCLIMemoryLimit"
    }

    private init() {}
}
