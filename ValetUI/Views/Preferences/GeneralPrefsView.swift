import SwiftUI

struct GeneralPrefsView: View {
    private var launchAtLoginService: LaunchAtLoginService { LaunchAtLoginService.shared }
    @State private var launchAtLogin: Bool = false
    @State private var autoRefresh: Bool = false
    @State private var refreshInterval: RefreshInterval = .thirtySeconds
    @State private var wpCLIMemoryLimit: String = "512M"

    private static let memoryOptions = ["256M", "512M", "1G", "2G"]

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .help("Start ValetUI automatically when you log in")
                    .onChange(of: launchAtLogin) { _, _ in
                        launchAtLoginService.toggle()
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
            } footer: {
                if autoRefresh {
                    Label("Auto refresh is on — status updates every \(refreshInterval.label.lowercased()).", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("WP-CLI Memory Limit", selection: $wpCLIMemoryLimit) {
                    ForEach(Self.memoryOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .onChange(of: wpCLIMemoryLimit) { _, new in
                    AppSettings.shared.wpCLIMemoryLimit = new
                }
            } header: {
                Text("WordPress")
                Text("PHP memory limit passed to WP-CLI during site creation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Label("WP-CLI memory limit is set to \(wpCLIMemoryLimit).", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadValues() }
    }

    private func loadValues() {
        launchAtLogin = launchAtLoginService.isEnabled
        autoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
        let raw = UserDefaults.standard.double(forKey: "refreshInterval")
        refreshInterval = RefreshInterval(rawValue: raw) ?? .thirtySeconds
        wpCLIMemoryLimit = AppSettings.shared.wpCLIMemoryLimit
    }
}
