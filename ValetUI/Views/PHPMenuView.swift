import SwiftUI

struct PHPMenuView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        Menu {
            if vm.phpVersions.isEmpty {
                Text("No PHP versions found")
                    .foregroundStyle(.secondary)
                Text("Install via: brew install php@8.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.phpVersions) { version in
                    Button {
                        guard !version.isCurrent else { return }
                        Task { await vm.switchPHP(to: version) }
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
            }
        } label: {
            Label {
                Text("PHP")
                Text(vm.currentPHP)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
        }
    }
}
