import SwiftUI

struct DeleteSiteView: View {
    let site: Site
    @Environment(AppViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var deleter = SiteDeleterService()
    @State private var plan: SiteDeleterService.DeletionPlan?
    @State private var dbUser: String = "root"
    @State private var dbPass: String = "root"
    @State private var isLoadingPlan = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete \(site.name)")
                        .font(.headline)
                    Text("This cannot be undone (files go to Trash)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            if deleter.isComplete {
                completionView
            } else if deleter.isRunning || isLoadingPlan {
                progressView
            } else {
                confirmationView
            }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .task { await loadPlan() }
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let plan {
                // What will be deleted
                VStack(alignment: .leading, spacing: 8) {
                    deletionRow(
                        icon: "folder.fill",
                        color: .orange,
                        label: "Site Folder",
                        detail: plan.site.path
                    )

                    if let db = plan.dbName {
                        deletionRow(
                            icon: "cylinder.fill",
                            color: .blue,
                            label: "Database",
                            detail: db
                        )
                    }

                    deletionRow(
                        icon: "doc.fill",
                        color: .purple,
                        label: "Nginx Config",
                        detail: (plan.nginxConfigPath as NSString).lastPathComponent
                    )

                    if !plan.certPaths.filter({ FileManager.default.fileExists(atPath: $0) }).isEmpty {
                        deletionRow(
                            icon: "lock.fill",
                            color: .green,
                            label: "SSL Certificates",
                            detail: "\(site.name).\(ValetConfigReader.readConfig()?.tld ?? "test").*"
                        )
                    }

                    if plan.symlinkPath != nil {
                        deletionRow(
                            icon: "link",
                            color: .gray,
                            label: "Valet Link",
                            detail: "~/.config/valet/Sites/\(site.name)"
                        )
                    }
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                // DB credentials
                if plan.dbName != nil {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DB User").font(.caption).foregroundStyle(.secondary)
                            TextField("root", text: $dbUser).textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DB Password").font(.caption).foregroundStyle(.secondary)
                            SecureField("root", text: $dbPass).textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Delete Site") {
                    guard let plan else { return }
                    Task {
                        await deleter.delete(plan: plan, dbUser: dbUser, dbPass: dbPass)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoadingPlan {
                HStack {
                    ProgressView()
                    Text("Analysing site…")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(SiteDeleterService.Step.allCases, id: \.self) { step in
                    stepRow(step)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func stepRow(_ step: SiteDeleterService.Step) -> some View {
        HStack(spacing: 10) {
            stepIcon(for: deleter.stepStates[step] ?? .pending)
                .frame(width: 18)
            Text(step.rawValue)
            Spacer()
            if case .skipped = deleter.stepStates[step] {
                Text("skipped").font(.caption).foregroundStyle(.tertiary)
            } else if case .failed(let msg) = deleter.stepStates[step] {
                Text(msg).font(.caption).foregroundStyle(.red).lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func stepIcon(for state: SiteDeleterService.StepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running:
            ProgressView().scaleEffect(0.7)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("\(site.name) deleted")
                .font(.title3.bold())

            Text("Files moved to Trash · Database dropped · Domain freed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = deleter.errorMessage {
                Text("⚠ \(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button("Done") {
                dismiss()
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func deletionRow(icon: String, color: Color, label: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func loadPlan() async {
        isLoadingPlan = true
        plan = await deleter.buildPlan(for: site)
        // Pre-fill DB credentials from WP installer defaults
        dbUser = UserDefaults.standard.string(forKey: "wpDBUser") ?? "root"
        dbPass = UserDefaults.standard.string(forKey: "wpDBPass") ?? "root"
        isLoadingPlan = false
    }
}
