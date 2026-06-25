import SwiftUI

enum PanelDestination {
    case sites, php, services, logs
}

struct MenuContentView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow
    @State private var destination: PanelDestination? = nil

    var body: some View {
        if !vm.isBrewInstalled || !vm.isValetInstalled {
            OnboardingMenuView()
                .environment(vm)
        } else if let dest = destination {
            destinationView(dest)
        } else {
            mainPanel
        }
    }

    // MARK: - Destination router

    @ViewBuilder
    private func destinationView(_ dest: PanelDestination) -> some View {
        switch dest {
        case .sites:
            SitesPanelView(onBack: { destination = nil })
                .environment(vm)
        case .php:
            PHPPanelView(onBack: { destination = nil })
                .environment(vm)
        case .services:
            ServicesPanelView(onBack: { destination = nil })
                .environment(vm)
        case .logs:
            LogsPanelView(onBack: { destination = nil })
        }
    }

    // MARK: - Main panel

    private var mainPanel: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, 10)
                .padding(.top, 10)

            if let error = vm.anyError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red)
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }

            VStack(spacing: 0) {
                PanelRow(
                    icon: "arrow.clockwise",
                    label: vm.isRefreshing ? "Refreshing…" : "Refresh",
                    isDisabled: vm.isRefreshing
                ) {
                    Task { await vm.refresh() }
                }

                PanelDivider()

                PanelRowCustomIcon(
                    image: WordPressLogo.nsImage(size: 16),
                    label: "New WordPress Site…",
                    isDisabled: !vm.isWPCLIInstalled || !vm.isMySQLInstalled
                ) {
                    openWindow(id: "new-site")
                    NSApp.activate(ignoringOtherApps: true)
                }

                PanelNavRow(icon: "globe", label: "Sites") { destination = .sites }
                PanelDivider()
                PanelNavRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    label: "PHP \(vm.phpViewModel.currentVersion)"
                ) { destination = .php }
                PanelDivider()
                PanelNavRow(icon: "gearshape.2", label: "Services") { destination = .services }
                PanelNavRow(icon: "list.bullet.rectangle", label: "Logs") { destination = .logs }
                PanelDivider()

                PanelRow(icon: "gearshape", label: "Preferences…") {
                    openWindow(id: "preferences")
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows
                        .first { $0.title == "Preferences" }?
                        .makeKeyAndOrderFront(nil)
                }

                PanelDivider()

                PanelRow(icon: "power", label: "Quit ValetUI", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280)
        .onAppear { Task { await vm.refresh() } }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("ValetUI")
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(vm.valetStatus.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                StatChip(icon: "chevron.left.forwardslash.chevron.right", label: "PHP", value: vm.phpViewModel.currentVersion)
                StatChip(icon: "globe", label: "Sites", value: "\(vm.sites.count)")
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusColor: Color {
        switch vm.valetStatus {
        case .running: return .green
        case .stopped: return .red
        case .unknown: return .orange
        }
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Nav Row

struct PanelNavRow: View {
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
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
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
    }
}
