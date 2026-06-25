import SwiftUI
import AppKit

struct AboutPrefsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }

            VStack(spacing: 4) {
                Text("ValetUI")
                    .font(.title2.bold())
                Text("Version \(AppConstants.appVersion)")
                    .foregroundStyle(.secondary)
                Text(Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("A native macOS menu bar app for Laravel Valet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Check for Updates") {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/naveenkharwar/ValetUI/releases")!
                    )
                }
                Button("View Source on GitHub") {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/naveenkharwar/ValetUI")!
                    )
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
