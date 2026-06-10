import SwiftUI

struct TerminalPrefsView: View {
    @State private var selectedTerminalID: String = "terminal"

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
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedTerminalID = UserDefaults.standard.string(forKey: "defaultTerminalID") ?? "terminal"
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
