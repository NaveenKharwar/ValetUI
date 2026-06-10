import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class SitesViewModel {
    private let shell: ShellCommandService

    init(shell: ShellCommandService) {
        self.shell = shell
    }

    func openInBrowser(_ site: Site) {
        guard let url = URL(string: site.url) else { return }
        NSWorkspace.shared.open(url)
    }

    func openInFinder(_ site: Site) {
        NSWorkspace.shared.open(site.pathURL)
    }

    func copyURL(_ site: Site) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(site.url, forType: .string)
    }
}
