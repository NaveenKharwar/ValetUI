import SwiftUI

struct TerminalPrefsView: View {
    @State private var selectedTerminalID: String = "com.apple.Terminal"

    private let installedTerminals = TerminalOption.installed

    var body: some View {
        Form {
            Section {
                if installedTerminals.isEmpty {
                    Text("No terminals detected. Terminal.app should always be available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(installedTerminals) { terminal in
                        terminalRow(terminal)
                    }
                }
            } header: {
                Text("Default Terminal")
                Text("Used when opening a terminal at a site directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                if let selected = installedTerminals.first(where: { $0.id == selectedTerminalID }) {
                    Label("Default terminal is set to \(selected.name).", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedTerminalID = UserDefaults.standard.string(forKey: "defaultTerminalID") ?? "com.apple.Terminal"
        }
    }

    private func terminalRow(_ terminal: TerminalOption) -> some View {
        Button {
            selectedTerminalID = terminal.id
            AppSettings.shared.defaultTerminalID = terminal.id
        } label: {
            HStack(spacing: 10) {
                if let icon = terminal.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text(terminal.name)
                Spacer()
                if selectedTerminalID == terminal.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
