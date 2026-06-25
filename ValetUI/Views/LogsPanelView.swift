import SwiftUI
import AppKit

struct LogsPanelView: View {
    let onBack: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            PanelBackHeader(title: "Logs", onBack: onBack)
            Divider()
            VStack(spacing: 0) {
                PanelRow(icon: "doc.text", label: "Valet Log") { openLog(AppConstants.valetLogPath) }
                PanelRow(icon: "doc.text", label: "Nginx Log") { openLog(AppConstants.nginxLogPath) }
                PanelRow(icon: "doc.text", label: "PHP Log") { openLog(AppConstants.phpLogPath) }
                PanelDivider()
                PanelRow(icon: "folder", label: "Open Logs Folder") {
                    let logsDir = "\(NSHomeDirectory())/.config/valet/Log"
                    NSWorkspace.shared.open(URL(fileURLWithPath: logsDir))
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }

    private func openLog(_ path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        openWindow(id: "log-viewer", value: expandedPath)
        NSApp.activate(ignoringOtherApps: true)
    }
}
