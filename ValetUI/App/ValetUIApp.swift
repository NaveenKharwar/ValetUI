import SwiftUI
import ServiceManagement

@main
struct ValetUIApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(appViewModel)
        } label: {
            MenuBarIcon(status: appViewModel.valetStatus, isRefreshing: appViewModel.isRefreshing)
        }
        .menuBarExtraStyle(.menu)

        Window("New WordPress Site", id: "new-site") {
            NewSiteView()
                .onDisappear {
                    Task { await appViewModel.refresh() }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        WindowGroup("Delete Site", id: "delete-site", for: Site.self) { $site in
            if let site {
                DeleteSiteView(site: site)
                    .environment(appViewModel)
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        WindowGroup("Subdomains", id: "subdomains", for: Site.self) { $site in
            if let site {
                SubdomainManagerView(site: site)
                    .onDisappear {
                        Task { await appViewModel.refresh() }
                    }
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        WindowGroup("Log Viewer", id: "log-viewer", for: String.self) { $logPath in
            if let logPath {
                LogViewerView(logPath: logPath)
            }
        }
        .defaultPosition(.center)
    }
}

private struct MenuBarIcon: View {
    let status: ValetStatus
    let isRefreshing: Bool

    var body: some View {
        Image(systemName: isRefreshing ? "arrow.clockwise" : (status == .running ? "v.circle.fill" : "v.circle"))
            .foregroundStyle(isRefreshing ? Color.primary : (status == .running ? Color.green : Color.red))
    }
}
