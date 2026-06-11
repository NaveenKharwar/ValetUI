import SwiftUI

struct ServicesMenuView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        Menu {
            // Valet-level restart
            Button {
                Task { await vm.servicesViewModel.restartValet() }
            } label: {
                Label("Restart Valet", systemImage: "arrow.clockwise.circle")
            }

            Divider()

            // Individual services from brew services list
            if vm.servicesViewModel.services.isEmpty {
                Button {
                    Task { await vm.servicesViewModel.restartNamed("nginx") }
                } label: {
                    Label("Restart Nginx", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await vm.servicesViewModel.restartNamed("php") }
                } label: {
                    Label("Restart PHP-FPM", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await vm.servicesViewModel.restartNamed("dnsmasq") }
                } label: {
                    Label("Restart DNSMasq", systemImage: "arrow.clockwise")
                }
            } else {
                ForEach(vm.servicesViewModel.services) { service in
                    Button {
                        Task { await vm.servicesViewModel.restart(service) }
                    } label: {
                        HStack {
                            Label(service.displayName, systemImage: "arrow.clockwise")
                            Spacer()
                            Circle()
                                .fill(service.isRunning ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        } label: {
            Label("Services", systemImage: "gearshape.2")
        }
    }
}
