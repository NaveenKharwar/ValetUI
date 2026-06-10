import Foundation
import ServiceManagement
import Observation

@Observable
@MainActor
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    private func enable() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("LaunchAtLogin enable failed: \(error.localizedDescription)")
        }
    }

    private func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("LaunchAtLogin disable failed: \(error.localizedDescription)")
        }
    }

    private init() {}
}
