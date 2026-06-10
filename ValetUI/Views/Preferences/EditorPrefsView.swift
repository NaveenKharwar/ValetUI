import SwiftUI

struct EditorPrefsView: View {
    @State private var selectedEditorID: String = ""
    @State private var customEditorPath: String = ""

    private let installedEditors = EditorOption.installed

    var body: some View {
        Form {
            Section {
                if installedEditors.isEmpty {
                    Text("No supported editors found. Install VS Code, Zed, Cursor, or PhpStorm.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(installedEditors) { editor in
                        editorRow(editor)
                    }

                    // Custom entry
                    editorRowCustom()
                }
            } header: {
                Text("Default Editor")
                Text("Used when opening a site folder from the Sites menu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedEditorID == "custom" {
                Section {
                    TextField("/Applications/MyEditor.app", text: $customEditorPath)
                        .onChange(of: customEditorPath) { _, new in
                            AppSettings.shared.customEditorPath = new
                        }

                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes = [.application]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications")
                        if panel.runModal() == .OK, let url = panel.url {
                            customEditorPath = url.path
                            AppSettings.shared.customEditorPath = url.path
                        }
                    }
                } header: {
                    Text("Custom Editor Path")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedEditorID = UserDefaults.standard.string(forKey: "defaultEditorID") ?? ""
            customEditorPath = UserDefaults.standard.string(forKey: "customEditorPath") ?? ""
        }
    }

    private func editorRow(_ editor: EditorOption) -> some View {
        Button {
            selectedEditorID = editor.id
            AppSettings.shared.defaultEditorID = editor.id
        } label: {
            HStack(spacing: 10) {
                if let icon = editor.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text(editor.name)
                Spacer()
                if selectedEditorID == editor.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func editorRowCustom() -> some View {
        Button {
            selectedEditorID = "custom"
            AppSettings.shared.defaultEditorID = "custom"
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "app.badge.checkmark")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
                Text("Custom…")
                Spacer()
                if selectedEditorID == "custom" {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
