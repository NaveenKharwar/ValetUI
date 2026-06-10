import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPrefsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")

            EditorPrefsView()
                .tabItem { Label("Editor", systemImage: "curlybraces") }
                .tag("editor")

            TerminalPrefsView()
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .tag("terminal")

            ValetPrefsView()
                .tabItem { Label("Valet", systemImage: "v.circle") }
                .tag("valet")
        }
        .frame(width: 520)
        .fixedSize(horizontal: true, vertical: false)
    }
}
