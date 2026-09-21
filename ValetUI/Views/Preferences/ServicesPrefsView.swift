import SwiftUI

struct ServicesPrefsView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Restart All
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Restart Valet")
                                    .font(.body)
                                Text("Restarts nginx and the active PHP-FPM pool.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restart Valet") {
                                Task { await vm.servicesViewModel.restartValet() }
                            }
                            .disabled(vm.servicesViewModel.notices["_valet"] != nil)
                        }

                        if let notice = vm.servicesViewModel.notices["_valet"] {
                            ServiceNoticeView(notice: notice)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: vm.servicesViewModel.notices["_valet"])
                } label: {
                    Label("All Services", systemImage: "gearshape.2")
                        .font(.headline)
                }

                // Individual services
                GroupBox {
                    if vm.servicesViewModel.services.isEmpty {
                        Text("No services detected. Try refreshing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(vm.servicesViewModel.services.enumerated()), id: \.element.id) { index, service in
                                if index > 0 { Divider() }
                                ServicePrefsRow(service: service)
                                    .environment(vm)
                            }
                        }
                    }
                } label: {
                    Label("Individual Services", systemImage: "list.bullet")
                        .font(.headline)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 300)
        .onAppear { Task { await vm.servicesViewModel.refresh() } }
    }
}

// MARK: - Service Row

private struct ServicePrefsRow: View {
    let service: ServiceStatus
    @Environment(AppViewModel.self) private var vm

    private var notice: ServiceNotice? {
        vm.servicesViewModel.notices[service.brewServiceName]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(service.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(service.displayName)
                    .font(.body)

                Spacer()

                HStack(spacing: 6) {
                    if !service.isRunning {
                        Button("Start") {
                            Task { await vm.servicesViewModel.start(service) }
                        }
                        .disabled(notice != nil)
                    } else {
                        Button("Stop") {
                            Task { await vm.servicesViewModel.stop(service) }
                        }
                        .disabled(notice != nil)
                    }

                    Button("Restart") {
                        Task { await vm.servicesViewModel.restart(service) }
                    }
                    .disabled(notice != nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)

            if let notice {
                ServiceNoticeView(notice: notice)
                    .padding(.leading, 18)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: notice)
    }
}

// MARK: - Notice View

struct ServiceNoticeView: View {
    let notice: ServiceNotice

    var body: some View {
        HStack(spacing: 6) {
            switch notice {
            case .busy(let msg):
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 14, height: 14)
                Text(msg)
                    .foregroundStyle(.secondary)
            case .success(let msg):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(msg)
                    .foregroundStyle(.secondary)
            case .failure(let msg):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .font(.caption)
    }
}
