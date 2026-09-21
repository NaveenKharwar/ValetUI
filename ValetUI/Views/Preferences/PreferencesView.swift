import SwiftUI

struct PreferencesView: View {
    @State private var selection: String? = "general"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("General",     systemImage: "gearshape")          .tag("general")
                Label("Editor",      systemImage: "curlybraces")         .tag("editor")
                Label("Terminal",    systemImage: "terminal")            .tag("terminal")
                Label("Valet",       systemImage: "v.circle")            .tag("valet")
                Label("Services",    systemImage: "gearshape.2")         .tag("services")
                Label("Diagnostics", systemImage: "stethoscope")         .tag("diagnostics")
                Label("About",       systemImage: "info.circle")         .tag("about")
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            switch selection {
            case "general":     GeneralPrefsView()
            case "editor":      EditorPrefsView()
            case "terminal":    TerminalPrefsView()
            case "valet":       ValetPrefsView()
            case "services":    ServicesPrefsView()
            case "diagnostics": DiagnosticsView()
            default:            AboutPrefsView()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
