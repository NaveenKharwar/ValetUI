import SwiftUI

struct OnboardingMenuView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        Text("ValetUI — Setup Required")
            .font(.headline)

        Divider()

        // Checklist
        requirementRow(met: vm.isBrewInstalled,   label: "Homebrew")
        requirementRow(met: vm.isValetInstalled,  label: "Laravel Valet")
        requirementRow(met: vm.isPHPInstalled,    label: "PHP")
        requirementRow(met: vm.isWPCLIInstalled,  label: "WP-CLI", optional: true)
        requirementRow(met: vm.isMySQLInstalled,  label: "MySQL",  optional: true)

        Divider()

        Text("See README → Prerequisites for setup instructions.")
            .font(.caption)
            .foregroundStyle(.secondary)

        // Check again after manual install
        Button {
            Task {
                await vm.checkDependenciesPublic()
                await vm.refresh()
            }
        } label: {
            Label("Check Again", systemImage: "arrow.clockwise")
        }

        Divider()

        Button("Quit ValetUI") { NSApplication.shared.terminate(nil) }
    }

    // MARK: - Row

    @ViewBuilder
    private func requirementRow(met: Bool, label: String, optional: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : (optional ? "minus.circle" : "xmark.circle.fill"))
                .foregroundStyle(met ? .green : (optional ? .secondary : .red))
            Text(label)
                .foregroundStyle(met ? .primary : (optional ? .secondary : .primary))
            if optional && !met {
                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

}
