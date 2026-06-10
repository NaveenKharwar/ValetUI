import SwiftUI

struct StatusHeaderView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        // Status indicator
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(vm.valetStatus.displayName)
                .font(.system(.caption, design: .default).weight(.medium))
        }

        // PHP version
        HStack(spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("PHP \(vm.currentPHP)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Site count
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(siteCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch vm.valetStatus {
        case .running: return .green
        case .stopped: return .red
        case .unknown: return .orange
        }
    }

    private var siteCountLabel: String {
        let count = vm.sites.count
        return count == 1 ? "1 Site" : "\(count) Sites"
    }
}
