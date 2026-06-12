import SwiftUI

struct NewSiteView: View {
    @State private var installer = WordPressInstallerService()
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var siteName: String = ""
    @State private var baseDir: String = ""
    @State private var dbUser: String = "root"
    @State private var dbPass: String = "root"
    @State private var adminUser: String = "admin"
    @State private var adminPassword: String = "admin"
    @State private var adminEmail: String = "admin@example.com"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                WordPressLogoView(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New WordPress Site")
                        .font(.headline)
                    Text("Creates a local WordPress install via Valet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            if installer.isComplete {
                completionView
            } else if installer.isRunning || installer.errorMessage != nil {
                progressView
            } else {
                formView
            }
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            installer.reset()
            loadDefaults()
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                field(label: "Site Name", placeholder: "my-project", text: $siteName)
                    .onChange(of: siteName) { _, new in
                        siteName = new.lowercased()
                            .replacingOccurrences(of: " ", with: "-")
                            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Base Directory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("", text: $baseDir)
                            .textFieldStyle(.roundedBorder)
                        Button("Choose…") { chooseDirectory() }
                    }
                }

                if !siteName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("https://\(siteName).\(tld)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // WordPress admin credentials
            Text("WordPress Admin")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                field(label: "Username", placeholder: "admin", text: $adminUser)
                field(label: "Password", placeholder: "admin", text: $adminPassword, isSecure: true)
            }

            field(label: "Email", placeholder: "admin@example.com", text: $adminEmail)

            Divider()

            Text("Database")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                field(label: "DB User", placeholder: "root", text: $dbUser)
                field(label: "DB Password", placeholder: "root", text: $dbPass, isSecure: true)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Site") {
                    Task { await installer.install(
                        siteName: siteName,
                        baseDir: baseDir,
                        dbUser: dbUser,
                        dbPass: dbPass,
                        adminUser: adminUser,
                        adminPassword: adminPassword,
                        adminEmail: adminEmail
                    )}
                }
                .keyboardShortcut(.defaultAction)
                .disabled(siteName.isEmpty || baseDir.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(WordPressInstallerService.Step.allCases, id: \.self) { step in
                stepRow(step)
            }

            if let errorMessage = installer.errorMessage {
                Divider()
                ScrollView {
                    Text(errorMessage)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
                .padding(8)
                .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                HStack {
                    Spacer()
                    Button("Back") {
                        installer.reset()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func stepRow(_ step: WordPressInstallerService.Step) -> some View {
        HStack(spacing: 10) {
            stepIcon(for: installer.stepStates[step] ?? .pending)
                .frame(width: 18)
            Text(step.rawValue)
                .font(.system(.body, design: .default))

            Spacer()
        }
    }

    @ViewBuilder
    private func stepIcon(for state: WordPressInstallerService.StepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .running:
            ProgressView()
                .scaleEffect(0.7)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Site Ready!")
                .font(.title2.bold())

            VStack(spacing: 6) {
                infoRow(label: "URL", value: installer.siteURL)
                infoRow(label: "Admin", value: installer.siteURL + "/wp-admin")
                infoRow(label: "User", value: adminUser)
                infoRow(label: "Password", value: adminPassword)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Text("Terminal opened to run: valet secure \(siteName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Open in Browser") {
                    if let url = URL(string: installer.siteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Open Admin") {
                    if let url = URL(string: installer.siteURL + "/wp-admin") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Done") { dismiss() }
            }
        }
        .padding(24)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func field(label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isSecure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
    }

    private var tld: String {
        ValetConfigReader.readConfig()?.tld ?? "test"
    }

    private func loadDefaults() {
        // Base dir: first root path from valet config
        if let config = ValetConfigReader.readConfig() {
            let rootPaths = config.paths.filter { path in
                !config.paths.contains { other in
                    path != other && path.hasPrefix(other + "/")
                }
            }
            baseDir = rootPaths.first ?? NSHomeDirectory() + "/Sites"
        } else {
            baseDir = NSHomeDirectory() + "/Sites"
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: baseDir)
        if panel.runModal() == .OK, let url = panel.url {
            baseDir = url.path
        }
    }
}
