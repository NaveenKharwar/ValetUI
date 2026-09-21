import SwiftUI

struct DiagnosticsView: View {
    @State private var diagVM = DiagnosticsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Text("Run diagnostics to detect common Valet issues — port conflicts, missing sockets, MySQL errors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button {
                    Task { await diagVM.runDiagnostics() }
                } label: {
                    if diagVM.isRunning {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                            Text("Running…")
                        }
                    } else {
                        Text(diagVM.checks.isEmpty ? "Run Diagnostics" : "Run Again")
                    }
                }
                .disabled(diagVM.isRunning)
            }
            .padding(16)

            Divider()

            if diagVM.checks.isEmpty && !diagVM.isRunning {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Press \"Run Diagnostics\" to check service health")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Health checks
                        if !diagVM.checks.isEmpty {
                            GroupBox {
                                VStack(spacing: 0) {
                                    ForEach(Array(diagVM.checks.enumerated()), id: \.element.id) { index, check in
                                        if index > 0 { Divider() }
                                        CheckRow(check: check)
                                    }
                                }
                            } label: {
                                Label("Health Checks", systemImage: "checkmark.shield")
                                    .font(.headline)
                            }
                        }

                        // Recent errors
                        if !diagVM.recentErrors.isEmpty {
                            GroupBox {
                                ScrollView {
                                    Text(diagVM.recentErrors)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .padding(8)
                                }
                                .frame(maxHeight: 200)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            } label: {
                                Label("Recent Errors", systemImage: "exclamationmark.triangle")
                                    .font(.headline)
                            }
                        } else if !diagVM.checks.isEmpty {
                            GroupBox {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("No recent errors found in logs")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            } label: {
                                Label("Recent Errors", systemImage: "exclamationmark.triangle")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minHeight: 360)
    }
}

// MARK: - Check Row

private struct CheckRow: View {
    let check: DiagnosticCheck
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                statusIcon
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(check.name)
                        .font(.body)
                    Text(check.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if check.detail != nil {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if check.detail != nil {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                }
            }

            if isExpanded, let detail = check.detail {
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.leading, 26)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch check.status {
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .pending:
            ProgressView()
                .scaleEffect(0.7)
        }
    }
}
