import SwiftUI
import ServiceManagement

struct GeneralPrefsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var autoRefresh: Bool = false
    @State private var refreshInterval: RefreshInterval = .thirtySeconds

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .help("Start ValetUI automatically when you log in")
                    .onChange(of: launchAtLogin) { _, new in
                        if new {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }

                Toggle("Auto Refresh", isOn: $autoRefresh)
                    .help("Automatically refresh Valet status in the background")
                    .onChange(of: autoRefresh) { _, new in
                        UserDefaults.standard.set(new, forKey: "autoRefresh")
                    }

                if autoRefresh {
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    .onChange(of: refreshInterval) { _, new in
                        UserDefaults.standard.set(new.rawValue, forKey: "refreshInterval")
                    }
                }
            } header: {
                Text("Startup & Refresh")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version").foregroundStyle(.secondary)
                        Text(AppConstants.appVersion)
                    }
                    Spacer()
                    Button("Check for Updates") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/naveenkharwar/ValetUI/releases")!
                        )
                    }
                }

                HStack {
                    Text("GitHub").foregroundStyle(.secondary)
                    Spacer()
                    Button("View Source") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/naveenkharwar/ValetUI")!
                        )
                    }
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadValues() }
    }

    private func loadValues() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        autoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
        let raw = UserDefaults.standard.double(forKey: "refreshInterval")
        refreshInterval = RefreshInterval(rawValue: raw) ?? .thirtySeconds
    }
}
