import SwiftUI
import AppKit

struct SitesPanelView: View {
    let onBack: () -> Void
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            PanelBackHeader(title: "Sites", onBack: onBack)
            Divider()
            VStack(spacing: 0) {
                if vm.sites.isEmpty {
                    Text("No sites found")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(vm.sites) { site in
                        SitePanelRow(site: site)
                            .environment(vm)
                    }
                }
                if let config = ValetConfigReader.readConfig() {
                    let rootPaths = config.paths.filter { path in
                        !config.paths.contains { other in path != other && path.hasPrefix(other + "/") }
                    }
                    if !rootPaths.isEmpty {
                        PanelDivider()
                        PanelSectionHeader(title: "Parked Folders")
                        ForEach(rootPaths, id: \.self) { path in
                            PanelRow(icon: "folder", label: (path as NSString).lastPathComponent) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }
}

// MARK: - Site Panel Row (with expandable detail)

private struct SitePanelRow: View {
    let site: Site
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var isLoggingIn = false
    @State private var isCopyingLogin = false
    @State private var loginURLCopied = false
    @State private var loginError: String? = nil

    private var isWordPress: Bool {
        WPConfigService.isWordPressSite(at: site.path)
    }

    private var phpDisplayName: String? {
        guard let brewName = site.isolatedPHP else { return nil }
        return vm.phpViewModel.versions.first { $0.brewName == brewName }?.displayName ?? brewName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: site.isSecured ? "lock.fill" : "lock.open")
                        .font(.system(size: 12))
                        .foregroundStyle(site.isSecured ? .green : .secondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(site.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(phpDisplayName.map { "\(site.url) · \($0)" } ?? site.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.disabled)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(
                    isHovered ? Color.primary.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            if isExpanded {
                Divider().padding(.horizontal, 12)
            }

            // Expanded detail
            if isExpanded {
                VStack(spacing: 6) {
                    // Open group
                    SiteActionGroup {
                        SiteActionRow(icon: "safari", label: "Open in Browser") {
                            guard let url = URL(string: site.url) else { return }
                            NSWorkspace.shared.open(url)
                        }
                        if isWordPress {
                            Divider().padding(.leading, 36)
                            SiteActionRow(
                                icon: "person.badge.key",
                                label: isLoggingIn ? "Logging in…" : "Login as Admin"
                            ) {
                                guard !isLoggingIn, !isCopyingLogin else { return }
                                isLoggingIn = true
                                loginError = nil
                                Task {
                                    defer { isLoggingIn = false }
                                    let result = await WPAutoLoginService.generateAutoLoginURL(
                                        at: site.path, siteURL: site.url)
                                    if let urlString = result.url, let url = URL(string: urlString) {
                                        NSWorkspace.shared.open(url)
                                    } else {
                                        let alert = NSAlert()
                                        alert.messageText = "Login failed"
                                        alert.informativeText = result.error ?? "Unknown error"
                                        alert.alertStyle = .warning
                                        alert.runModal()
                                    }
                                }
                            }
                            Divider().padding(.leading, 36)
                            SiteActionRow(
                                icon: loginURLCopied ? "checkmark" : "link.badge.plus",
                                label: isCopyingLogin ? "Generating…" : (loginURLCopied ? "Copied!" : "Copy Login URL")
                            ) {
                                guard !isLoggingIn, !isCopyingLogin else { return }
                                isCopyingLogin = true
                                loginURLCopied = false
                                loginError = nil
                                Task {
                                    defer { isCopyingLogin = false }
                                    let result = await WPAutoLoginService.generateAutoLoginURL(
                                        at: site.path, siteURL: site.url)
                                    if let urlString = result.url {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(urlString, forType: .string)
                                        loginURLCopied = true
                                        try? await Task.sleep(for: .seconds(2))
                                        loginURLCopied = false
                                    } else {
                                        let alert = NSAlert()
                                        alert.messageText = "Login failed"
                                        alert.informativeText = result.error ?? "Unknown error"
                                        alert.alertStyle = .warning
                                        alert.runModal()
                                    }
                                }
                            }
                        }
                        if let editor = AppSettings.shared.resolvedEditor {
                            Divider().padding(.leading, 36)
                            SiteActionRow(icon: "curlybraces", label: "Open in \(editor.name)") {
                                editor.open(path: site.path)
                            }
                        }
                        Divider().padding(.leading, 36)
                        SiteActionRow(icon: "terminal", label: "Open in \(AppSettings.shared.resolvedTerminal?.name ?? "Terminal")") {
                            let terminal = AppSettings.shared.resolvedTerminal
                                ?? TerminalOption.all.first { $0.id == "com.apple.Terminal" }!
                            terminal.open(path: site.path)
                        }
                        Divider().padding(.leading, 36)
                        SiteActionRow(icon: "folder", label: "Open in Finder") {
                            NSWorkspace.shared.open(site.pathURL)
                        }
                        Divider().padding(.leading, 36)
                        SiteActionRow(icon: "doc.on.clipboard", label: "Copy URL") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(site.url, forType: .string)
                        }
                        Divider().padding(.leading, 36)
                        SiteActionRow(icon: "antenna.radiowaves.left.and.right", label: "Share Publicly…") {
                            Task { await vm.shareSite(site) }
                        }
                    }

                    // Manage group
                    SiteActionGroup {
                        SiteActionRow(icon: "network", label: "Manage Subdomains…") {
                            openWindow(id: "subdomains", value: site)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        if !vm.phpViewModel.versions.isEmpty {
                            Divider().padding(.leading, 36)
                            PHPVersionPicker(site: site)
                                .environment(vm)
                        }
                        Divider().padding(.leading, 36)
                        if site.isSecured {
                            SiteActionRow(icon: "lock.slash", label: "Remove HTTPS") {
                                Task { await vm.unsecureSite(site) }
                            }
                        } else {
                            SiteActionRow(icon: "lock", label: "Enable HTTPS") {
                                Task { await vm.secureSite(site) }
                            }
                        }
                    }

                    // Danger group
                    SiteActionGroup {
                        SiteActionRow(icon: "trash", label: "Delete Site…", isDestructive: true) {
                            openWindow(id: "delete-site", value: site)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Site Action Group

private struct SiteActionGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Site Action Row

private struct SiteActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 14)
                    .foregroundStyle(isDestructive ? .red : .secondary)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(isDestructive ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isHovered ? Color.primary.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PHP Version Picker (inline submenu)

private struct PHPVersionPicker: View {
    let site: Site
    @Environment(AppViewModel.self) private var vm
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12))
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                    Text("PHP Version")
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    // Default option
                    PHPPickerOption(
                        label: "Default (\(vm.phpViewModel.currentVersion))",
                        isSelected: site.isolatedPHP == nil
                    ) {
                        Task { await vm.unisolateSite(site) }
                    }

                    ForEach(vm.phpViewModel.versions) { version in
                        PHPPickerOption(
                            label: version.displayName,
                            isSelected: site.isolatedPHP == version.brewName
                        ) {
                            Task { await vm.isolateSite(site, version: version) }
                        }
                    }
                }
                .padding(.leading, 14)
            }
        }
    }
}

private struct PHPPickerOption: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isHovered ? Color.primary.opacity(0.08) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Back Header

struct PanelBackHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}
