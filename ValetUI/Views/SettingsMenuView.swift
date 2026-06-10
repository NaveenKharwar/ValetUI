import SwiftUI
import AppKit

struct SettingsMenuView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow
    @State private var showAbout = false

    private var settings: AppSettings { AppSettings.shared }
    private var launchAtLogin: LaunchAtLoginService { LaunchAtLoginService.shared }

    var body: some View {
        Menu {
            // Open Preferences window
            Button("Preferences…") {
                openWindow(id: "preferences")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            // Launch at Login
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                )
            )

            Divider()

            // Auto Refresh
            Toggle(
                "Auto Refresh",
                isOn: Binding(
                    get: { settings.autoRefresh },
                    set: { vm.toggleAutoRefresh(enabled: $0) }
                )
            )

            if settings.autoRefresh {
                Menu("Refresh Interval") {
                    ForEach(RefreshInterval.allCases) { interval in
                        Button {
                            vm.setupAutoRefresh(interval: interval)
                        } label: {
                            HStack {
                                Text(interval.label)
                                if settings.refreshInterval == interval {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button("About ValetUI") {
                showAboutPanel()
            }
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }

    private func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "ValetUI",
                .applicationVersion: AppConstants.appVersion,
                .credits: NSAttributedString(
                    string: "A native macOS menu bar app for Laravel Valet.\nhttps://github.com/naveenkharwar/ValetUI",
                    attributes: [.font: NSFont.systemFont(ofSize: 11)]
                )
            ]
        )
    }
}
