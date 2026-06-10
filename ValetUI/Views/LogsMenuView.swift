import SwiftUI
import AppKit

struct LogsMenuView: View {
    var body: some View {
        Menu {
            Button {
                openLog(AppConstants.valetLogPath)
            } label: {
                Label("Valet Log", systemImage: "doc.text")
            }

            Button {
                openLog(AppConstants.nginxLogPath)
            } label: {
                Label("Nginx Log", systemImage: "doc.text")
            }

            Button {
                openLog(AppConstants.phpLogPath)
            } label: {
                Label("PHP Log", systemImage: "doc.text")
            }

            Divider()

            Button {
                // Open the entire valet logs directory
                let logsDir = "\(NSHomeDirectory())/.config/valet/Log"
                NSWorkspace.shared.open(URL(fileURLWithPath: logsDir))
            } label: {
                Label("Open Logs Folder", systemImage: "folder")
            }
        } label: {
            Label("Logs", systemImage: "list.bullet.rectangle")
        }
    }

    private func openLog(_ path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        if FileManager.default.fileExists(atPath: expandedPath) {
            NSWorkspace.shared.open(url)
        } else {
            // Show in Finder even if log doesn't exist yet — open parent dir
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}
