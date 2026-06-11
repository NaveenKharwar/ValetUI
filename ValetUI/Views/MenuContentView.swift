import SwiftUI

struct MenuContentView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !vm.isBrewInstalled || !vm.isValetInstalled {
            OnboardingMenuView()
                .environment(vm)
        } else {
            mainMenu
        }
    }

    @ViewBuilder
    private var mainMenu: some View {
        // Status header — non-interactive info rows
        StatusHeaderView()
            .environment(vm)
            // Menu-style MenuBarExtra builds its content on every open —
            // refresh here so data is current without constant polling
            .onAppear {
                Task { await vm.refresh() }
            }

        Divider()

        // Refresh
        Button {
            Task { await vm.refresh() }
        } label: {
            Label(vm.isRefreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(vm.isRefreshing)

        Divider()

        // New WordPress Site
        Button {
            openWindow(id: "new-site")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label {
                Text("New WordPress Site…")
                    + ((!vm.isWPCLIInstalled || !vm.isMySQLInstalled)
                        ? Text(" (wp-cli & mysql required)").foregroundStyle(.secondary)
                        : Text(""))
            } icon: {
                Image(nsImage: WordPressLogo.nsImage(size: 16))
                    .opacity((!vm.isWPCLIInstalled || !vm.isMySQLInstalled) ? 0.4 : 1.0)
            }
        }
        .disabled(!vm.isWPCLIInstalled || !vm.isMySQLInstalled)

        // Sites
        SitesMenuView()
            .environment(vm)

        Divider()

        // PHP
        PHPMenuView()
            .environment(vm)

        Divider()

        // Services
        ServicesMenuView()
            .environment(vm)

        // Logs
        LogsMenuView()

        Divider()

        // Settings
        SettingsMenuView()
            .environment(vm)

        Divider()

        Button("Quit ValetUI") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")

        // Error banner (shown as disabled menu item)
        if let error = vm.anyError {
            Divider()
            Text("⚠ \(error)")
                .font(.caption)
                .foregroundStyle(.red)
                .truncationMode(.tail)
                .lineLimit(2)
        }
    }
}
