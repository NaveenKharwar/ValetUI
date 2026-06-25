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
    /// prefix → reachable; missing key = check pending
    var reachability: [String: Bool] = [:]

    private let service = SubdomainService.shared

    func load(site: Site) async {
        isLoading = true
        subdomains = await service.listSubdomains(for: site)
        isWordPressSite = WPConfigService.isWordPressSite(at: site.path)
        wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        isLoading = false
        await checkReachability()
    }

    func add(prefix: String, site: Site) async {
        errorMessage = nil
        successMessage = nil
        do {
            let subdomain = try await service.addSubdomain(prefix: prefix, site: site)
            successMessage = "\(subdomain.fullDomain) added — Valet serves it instantly, no config needed"
            await load(site: site)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ subdomain: Subdomain, site: Site) async {
        errorMessage = nil
        successMessage = nil

        // Secured subdomains have a cert + valet config + Sites symlink —
        // valet unsecure must clean those up (needs sudo, hence Terminal)
        if subdomain.isSecured {
            openTerminalToUnsecure(subdomain, removeAfter: true)
        }

        await service.removeSubdomain(subdomain)
        successMessage = "\(subdomain.fullDomain) removed"
        await load(site: site)
    }

    func applyWPConfigFix(site: Site) {
        errorMessage = nil
        successMessage = nil
        let result = WPConfigService.applyDynamicURLFix(at: site.path)
        switch result {
        case .success:
            successMessage = "✓ wp-config.php updated (backup saved as wp-config.php.valetui-backup)"
            wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        case .alreadyDynamic:
            wpConfigMode = WPConfigService.detectURLMode(at: site.path)
        case .notWordPress:
            break
        case .failed(let msg):
            errorMessage = "Could not update wp-config.php: \(msg)"
        }
    }

    // MARK: - HTTPS

    func secureSubdomain(_ subdomain: Subdomain, site: Site) {
        errorMessage = nil
        successMessage = nil

        guard Site.isValidName(subdomain.valetSiteName) else {
            errorMessage = "Unsupported name — run manually: valet secure \(subdomain.valetSiteName)"
            return
        }
        guard let terminal = resolvedTerminal() else {
            errorMessage = "No terminal found. Run manually: valet secure \(subdomain.valetSiteName)"
            return
        }

        // valet secure needs the subdomain to exist as a valet site — link it
        // to the same root as the parent. The symlink STAYS so a later
        // unsecure can find the site.
        let symlinkPath = symlinkPath(for: subdomain)
        if !FileManager.default.fileExists(atPath: symlinkPath) {
            try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: site.path)
        }

        terminal.open(path: NSHomeDirectory(), command: "valet secure \(subdomain.valetSiteName)")
        successMessage = "Terminal opened — enabling HTTPS for \(subdomain.fullDomain)"
    }

    func unsecureSubdomain(_ subdomain: Subdomain) {
        errorMessage = nil
        successMessage = nil
        openTerminalToUnsecure(subdomain, removeAfter: false)
        successMessage = "Terminal opened — removing HTTPS for \(subdomain.fullDomain)"
    }

    private func openTerminalToUnsecure(_ subdomain: Subdomain, removeAfter: Bool) {
        guard Site.isValidName(subdomain.valetSiteName), let terminal = resolvedTerminal() else {
            errorMessage = "Run manually: valet unsecure \(subdomain.valetSiteName)"
            return
        }
        // After unsecure the symlink has no further purpose — clean it up
        let symlink = symlinkPath(for: subdomain)
        let command = "valet unsecure \(subdomain.valetSiteName) && rm -f \"\(symlink)\""
        terminal.open(path: NSHomeDirectory(), command: command)
    }

    private func symlinkPath(for subdomain: Subdomain) -> String {
        let sitesDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/valet/Sites")
        return (sitesDir as NSString).appendingPathComponent(subdomain.valetSiteName)
    }

    private func resolvedTerminal() -> TerminalOption? {
        AppSettings.shared.resolvedTerminal
            ?? TerminalOption.all.first { $0.id == "com.apple.Terminal" }
    }

    // MARK: - Reachability

    func checkReachability() async {
        let targets = subdomains
        await withTaskGroup(of: (String, Bool).self) { group in
            for sub in targets {
                group.addTask {
                    guard let url = URL(string: sub.url) else { return (sub.prefix, false) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 3
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        // Any HTTP response (even 404/redirect) means nginx answered
                        return (sub.prefix, response is HTTPURLResponse)
                    } catch {
                        return (sub.prefix, false)
                    }
                }
            }
            for await (prefix, reachable) in group {
                reachability[prefix] = reachable
            }
        }
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
            Text("No subdomains tracked")
                .font(.headline)
            Text("Valet already serves any subdomain of **\(site.name).\(site.tld)** — try opening one in your browser.\nAdd it here to track it, enable HTTPS, and fix WordPress URLs.")
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
                    reachable: vm.reachability[subdomain.prefix],
                    onSecure: { vm.secureSubdomain(subdomain, site: site) },
                    onUnsecure: { vm.unsecureSubdomain(subdomain) },
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
                        newPrefix = SubdomainService.cleanPrefix(val) ?? ""
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

            Text("Valet serves subdomains of **\(site.name).\(site.tld)** automatically — no server config is created. ValetUI tracks this subdomain so you can enable HTTPS and check reachability.")
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
    let reachable: Bool?
    let onSecure: () -> Void
    let onUnsecure: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: subdomain.isSecured ? "lock.fill" : "lock.open")
                    .foregroundStyle(subdomain.isSecured ? .green : .orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(subdomain.fullDomain)
                            .font(.system(.body, design: .monospaced))
                        reachabilityDot
                    }
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
                    Text(subdomain.isSecured
                         ? "Terminal will open to remove the HTTPS certificate, then the subdomain is untracked. Site files are not affected."
                         : "The subdomain is untracked. Valet will still serve it — site files are not affected.")
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
                if subdomain.isSecured {
                    Button("Remove HTTPS") { onUnsecure() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                } else {
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

    @ViewBuilder
    private var reachabilityDot: some View {
        switch reachable {
        case .some(true):
            Circle().fill(.green).frame(width: 7, height: 7)
                .help("Responding")
        case .some(false):
            Circle().fill(.red).frame(width: 7, height: 7)
                .help("Not responding — is Valet running?")
        case .none:
            Circle().fill(.gray.opacity(0.4)).frame(width: 7, height: 7)
                .help("Checking…")
        }
    }
}
