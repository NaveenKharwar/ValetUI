import SwiftUI

struct SitesMenuView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        Menu {
            if vm.sites.isEmpty {
                Text("No sites found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.sites) { site in
                    SiteRowView(site: site)
                        .environment(vm)
                }
            }

            Divider()

            // Open each parked path from valet config
            if let config = ValetConfigReader.readConfig() {
                let rootPaths = config.paths.filter { path in
                    !config.paths.contains { other in
                        path != other && path.hasPrefix(other + "/")
                    }
                }
                ForEach(rootPaths, id: \.self) { path in
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    } label: {
                        Label(
                            (path as NSString).lastPathComponent,
                            systemImage: "folder"
                        )
                    }
                }
            }
        } label: {
            Label {
                Text("Sites")
                if !vm.sites.isEmpty {
                    Text("(\(vm.sites.count))")
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "globe")
            }
        }
    }
}
