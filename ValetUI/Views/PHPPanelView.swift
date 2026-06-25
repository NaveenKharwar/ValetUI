import SwiftUI

struct PHPPanelView: View {
    let onBack: () -> Void
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            PanelBackHeader(title: "PHP", onBack: onBack)
            Divider()
            VStack(spacing: 0) {
                if vm.phpViewModel.versions.isEmpty {
                    VStack(spacing: 6) {
                        Text("No PHP versions found")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Install via: brew install php@8.3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(vm.phpViewModel.versions) { version in
                        PHPVersionRow(version: version)
                            .environment(vm)
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Install more hint
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Want more PHP versions?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("brew install php@8.4 php@8.3 php@8.2 php@8.1", forType: .string)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                        Text("brew install php@8.4 php@8.3 …")
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }
}

// MARK: - PHP Version Row

private struct PHPVersionRow: View {
    let version: PHPVersion
    @Environment(AppViewModel.self) private var vm
    @State private var isHovered = false

    var body: some View {
        Button {
            guard !version.isCurrent else { return }
            Task { await vm.phpViewModel.switchTo(version) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(version.isCurrent ? .primary : .secondary)
                Text(version.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if version.isCurrent {
                    HStack(spacing: 4) {
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isHovered && !version.isCurrent ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(version.isCurrent)
        .onHover { isHovered = $0 }
    }
}
