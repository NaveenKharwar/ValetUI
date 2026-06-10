import SwiftUI

@Observable
@MainActor
final class SubdomainManagerViewModel {
    var subdomains: [Subdomain] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var wpConfigMode: WPConfigService.URLMode = .notDefined
    var isWordPressSite = false

    private let service = SubdomainService.shared

    func load(site: Site) async {
        isLoading = true
        subdomains = await service.listSubdomains(for: site)
        isWordPressSite = WPConfigService.isWordPressSite(at: site.path)
        wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        isLoading = false
    }

    func add(prefix: String, site: Site) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.addSubdomain(prefix: prefix, site: site)
            successMessage = "\(prefix).\(site.name).\(site.tld) added"
            await load(site: site)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ subdomain: Subdomain, site: Site) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.removeSubdomain(subdomain)
            successMessage = "\(subdomain.fullDomain) removed"
            await load(site: site)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyWPConfigFix(site: Site) {
        errorMessage = nil
        successMessage = nil
        let result = WPConfigService.applyDynamicURLFix(at: site.path)
        switch result {
        case .success:
            successMessage = "✓ wp-config.php updated — subdomains will work correctly"
            wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        case .alreadyDynamic:
            wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        case .notWordPress:
            break
        case .failed(let msg):
            errorMessage = "Could not update wp-config.php: \(msg)"
        }
    }

    func secureSubdomain(_ subdomain: Subdomain) {
        let terminal = AppSettings.shared.resolvedTerminal
            ?? TerminalOption.all.first { $0.id == "terminal" }

        guard let terminal else {
            errorMessage = "No terminal found. Run manually: valet secure \(subdomain.prefix).\(subdomain.siteName)"
            return
        }

        let sitesDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Sites")
        let symlinkPath = (sitesDir as NSString).appendingPathComponent("\(subdomain.prefix).\(subdomain.siteName)")
        let rootPath = extractRootFromNginxConfig(at: subdomain.nginxConfigPath)

        if let rootPath {
            try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: rootPath)
        }

        let siteName = "\(subdomain.prefix).\(subdomain.siteName)"
        let command = rootPath != nil
            ? "valet secure \(siteName) && echo '✓ HTTPS enabled for \(subdomain.fullDomain)' && rm -f '\(symlinkPath)'"
            : "valet secure \(siteName)"

        terminal.open(path: NSHomeDirectory(), command: command)
        successMessage = "Terminal opened — enabling HTTPS for \(subdomain.fullDomain)"
    }

    private func extractRootFromNginxConfig(at path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let pattern = #"root\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[range])
    }
}

// MARK: - Main View

struct SubdomainManagerView: View {
    let site: Site
    @State private var vm = SubdomainManagerViewModel()
    @State private var showAddSheet = false
    @State private var newPrefix = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subdomains")
                        .font(.headline)
                    Text(site.name + "." + site.tld)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Subdomain", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // WordPress URL config banner — always visible for WP sites
            if vm.isWordPressSite {
                wpConfigBanner
                Divider()
            }

            if vm.isLoading {
                ProgressView("Loading…")
                    .padding(40)
            } else if vm.subdomains.isEmpty {
                emptyState
            } else {
                subdomainList
            }

            // Status bar
            if vm.errorMessage != nil || vm.successMessage != nil {
                Divider()
                HStack {
                    if let err = vm.errorMessage {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        Text(err).foregroundStyle(.red)
                    } else if let ok = vm.successMessage {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(ok).foregroundStyle(.green)
                    }
                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showAddSheet) {
            addSheet
        }
        .task {
            await vm.load(site: site)
        }
    }

    // MARK: - WordPress URL Config Banner

    private var wpConfigBanner: some View {
        HStack(spacing: 10) {
            switch vm.wpConfigMode {
            case .dynamic:
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WordPress URL: Ready for subdomains")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    Text("wp-config.php uses dynamic URL — all subdomains will work correctly")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

            case .hardcoded(let home, _):
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WordPress URL: Ready for subdomains")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    Text("wp-config.php uses \(home) — correct setup for WPML and multi-domain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()

            case .notDefined:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WordPress URL: Uses database value")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text("WordPress reads URL from DB (main domain only) — subdomains will redirect")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Fix Now") {
                    vm.applyWPConfigFix(site: site)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(bannerBackground)
    }

    private var bannerBackground: Color {
        switch vm.wpConfigMode {
        case .dynamic, .hardcoded: return Color.green.opacity(0.08)
        case .notDefined: return Color.orange.opacity(0.08)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No subdomains configured")
                .font(.headline)
            Text("Add a subdomain to serve \(site.name).\(site.tld) under a prefix like\n**api.\(site.name).\(site.tld)** or **fr.\(site.name).\(site.tld)**")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add First Subdomain") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    // MARK: - List

    private var subdomainList: some View {
        VStack(spacing: 0) {
            ForEach(vm.subdomains) { subdomain in
                SubdomainRowView(
                    subdomain: subdomain,
                    onSecure: { vm.secureSubdomain(subdomain) },
                    onDelete: { Task { await vm.remove(subdomain, site: site) } }
                )
                Divider().padding(.leading, 16)
            }
        }
    }

    // MARK: - Add Sheet

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Subdomain")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Prefix")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. fr, api, staging", text: $newPrefix)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: newPrefix) { _, val in
                        newPrefix = val.lowercased()
                            .replacingOccurrences(of: " ", with: "-")
                            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                    }
            }

            if !newPrefix.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("http://\(newPrefix).\(site.name).\(site.tld)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            Text("A new Nginx config will be created and Nginx reloaded automatically. The subdomain will point to the same directory as **\(site.name).\(site.tld)**.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") {
                    newPrefix = ""
                    showAddSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let prefix = newPrefix
                    newPrefix = ""
                    showAddSheet = false
                    Task { await vm.add(prefix: prefix, site: site) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPrefix.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

// MARK: - Row

private struct SubdomainRowView: View {
    let subdomain: Subdomain
    let onSecure: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: subdomain.isSecured ? "lock.fill" : "lock.open")
                    .foregroundStyle(subdomain.isSecured ? .green : .orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subdomain.fullDomain)
                        .font(.system(.body, design: .monospaced))
                    Text(subdomain.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if let url = URL(string: subdomain.url) { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.plain)
                .help("Open in Browser")

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(subdomain.url, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .help("Copy URL")

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Remove subdomain")
                .confirmationDialog(
                    "Remove \(subdomain.fullDomain)?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive) { onDelete() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The Nginx config will be deleted and Nginx reloaded. Site files are not affected.")
                }
            }

            // HTTPS status row
            HStack {
                Image(systemName: subdomain.isSecured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(subdomain.isSecured ? .green : .orange)
                Text(subdomain.isSecured ? "HTTPS enabled" : "HTTP only — not secure")
                    .font(.caption)
                    .foregroundStyle(subdomain.isSecured ? .green : .orange)
                Spacer()
                if !subdomain.isSecured {
                    Button("Enable HTTPS") { onSecure() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
            .padding(.leading, 28)
            .padding(.trailing, 16)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}
