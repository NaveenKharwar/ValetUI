import AppKit

extension NSWorkspace {
    func openInConsole(_ path: String) {
        let consoleURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
        let fileURL = URL(fileURLWithPath: path)
        open([fileURL], withApplicationAt: consoleURL, configuration: .init()) { _, _ in }
    }

    func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            activateFileViewerSelecting([url])
        } else {
            // Open parent directory if file doesn't exist yet
            open(url.deletingLastPathComponent())
        }
    }
}
