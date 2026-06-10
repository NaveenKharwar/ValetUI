import SwiftUI
import AppKit

struct SiteRowView: View {
    let site: Site
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Menu {
            // Open in Browser
            Button {
                guard let url = URL(string: site.url) else { return }
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }

            // Open in Editor
            if let editor = AppSettings.shared.resolvedEditor {
                Button {
                    editor.open(path: site.path)
                } label: {
                    Label("Open in \(editor.name)", systemImage: "curlybraces")
                }
            }

            // Open in Terminal
            Button {
                let terminal = AppSettings.shared.resolvedTerminal
                    ?? TerminalOption.all.first { $0.id == "terminal" }!
                terminal.open(path: site.path)
            } label: {
                let terminalName = AppSettings.shared.resolvedTerminal?.name ?? "Terminal"
                Label("Open in \(terminalName)", systemImage: "terminal")
            }

            // Open Folder in Finder
            Button {
                NSWorkspace.shared.open(site.pathURL)
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }

            // Copy URL
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(site.url, forType: .string)
            } label: {
                Label("Copy URL", systemImage: "doc.on.clipboard")
            }

            Divider()

            // Manage Subdomains
            Button {
                openWindow(id: "subdomains", value: site)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Manage Subdomains…", systemImage: "network")
            }

            Divider()

            // Delete Site
            Button {
                openWindow(id: "delete-site", value: site)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Delete Site…", systemImage: "trash")
            }

            Divider()

            // Secure / Unsecure
            if site.isSecured {
                Button {
                    let alert = NSAlert()
                    alert.messageText = "Remove HTTPS for \(site.name).\(site.tld)?"
                    alert.informativeText = "Terminal will open and run: valet unsecure \(site.name)\n\nThis requires your password."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open Terminal")
                    alert.addButton(withTitle: "Cancel")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        Task { await vm.unsecureSite(site) }
                    }
                } label: {
                    Label("Remove HTTPS", systemImage: "lock.slash")
                }
            } else {
                Button {
                    let alert = NSAlert()
                    alert.messageText = "Enable HTTPS for \(site.name).\(site.tld)?"
                    alert.informativeText = "Terminal will open and run: valet secure \(site.name)\n\nThis requires your password."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Open Terminal")
                    alert.addButton(withTitle: "Cancel")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        Task { await vm.secureSite(site) }
                    }
                } label: {
                    Label("Enable HTTPS", systemImage: "lock")
                }
            }

        } label: {
            HStack {
                Image(systemName: site.isSecured ? "lock.fill" : "lock.open")
                    .foregroundStyle(site.isSecured ? .green : .secondary)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 0) {
                    Text(site.name)
                    Text(site.url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
