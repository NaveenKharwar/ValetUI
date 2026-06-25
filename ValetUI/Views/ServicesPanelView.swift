import SwiftUI

struct ServicesPanelView: View {
    let onBack: () -> Void
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            PanelBackHeader(title: "Services", onBack: onBack)
            Divider()
            VStack(spacing: 0) {
                PanelSectionHeader(title: "All Services")
                ServiceActionRow(icon: "arrow.clockwise.circle", label: "Restart Valet") {
                    Task { await vm.servicesViewModel.restartValet() }
                }
                PanelDivider()
                PanelSectionHeader(title: "Individual Services")
                if vm.servicesViewModel.services.isEmpty {
                    FallbackServiceRow(name: "Nginx", restartName: "nginx").environment(vm)
                    FallbackServiceRow(name: "PHP-FPM", restartName: "php").environment(vm)
                    FallbackServiceRow(name: "DNSMasq", restartName: "dnsmasq").environment(vm)
                } else {
                    ForEach(vm.servicesViewModel.services) { service in
                        ServiceRow(service: service).environment(vm)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }
}

// MARK: - Service Row

private struct ServiceRow: View {
    let service: ServiceStatus
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(service.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(service.displayName)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            RestartButton { Task { await vm.servicesViewModel.restart(service) } }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Fallback Service Row

private struct FallbackServiceRow: View {
    let name: String
    let restartName: String
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            RestartButton { Task { await vm.servicesViewModel.restartNamed(restartName) } }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Restart Button

private struct RestartButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("Restart")
                .font(.caption)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Service Action Row

private struct ServiceActionRow: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
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
    }
}
