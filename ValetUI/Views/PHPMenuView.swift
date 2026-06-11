import SwiftUI

struct PHPMenuView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        Menu {
            if vm.phpViewModel.versions.isEmpty {
                Text("No PHP versions found")
                    .foregroundStyle(.secondary)
                Text("Install via: brew install php@8.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.phpViewModel.versions) { version in
                    Button {
                        guard !version.isCurrent else { return }
                        Task { await vm.phpViewModel.switchTo(version) }
                    } label: {
                        HStack {
                            Text(version.displayName)
                            if version.isCurrent {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(version.isCurrent)
                }

                // Single version installed — explain why there's nothing to switch to
                if vm.phpViewModel.versions.count == 1 {
                    Divider()
                    Text("Only one version installed")
                        .foregroundStyle(.secondary)
                    Text("Add more: brew install php@8.4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label {
                Text("PHP")
                Text(vm.phpViewModel.currentVersion)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
        }
    }
}
