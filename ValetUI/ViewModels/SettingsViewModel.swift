import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    let settings = AppSettings.shared
    let launchAtLogin = LaunchAtLoginService.shared

    init() {}
}
