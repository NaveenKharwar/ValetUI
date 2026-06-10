import Foundation
import Observation

@Observable
@MainActor
final class ServicesViewModel {
    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }
}
