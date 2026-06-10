import Foundation
import Observation

@Observable
@MainActor
final class PHPViewModel {
    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }
}
