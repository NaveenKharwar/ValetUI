import SwiftUI

struct ValetPrefsView: View {
    @State private var tld: String = ""
    @State private var loopback: String = ""
    @State private var shareTool: String = ""
    @State private var paths: [String] = []
    @State private var saveStatus: String? = nil
    @State private var showAddPath = false
    @State private var newPath: String = ""

    var body: some View {
        Form {
            // TLD
            Section {
                HStack {
                    TextField("test", text: $tld)
                        .frame(width: 120)
                    Text("e.g.  mysite.\(tld.isEmpty ? "test" : tld)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("TLD (Top Level Domain)")
                Text("Requires Valet restart after change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Loopback IP
            Section {
                TextField("127.0.0.1", text: $loopback)
                    .frame(width: 160)
            } header: {
                Text("Loopback IP")
            }

            // Share tool
            Section {
                Picker("Share Tool", selection: $shareTool) {
                    Text("expose").tag("expose")
                    Text("ngrok").tag("ngrok")
                    Text("cloudflared").tag("cloudflared")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            } header: {
                Text("Public Sharing Tool")
                Text("Used by 'valet share'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Parked paths
            Section {
                ForEach(paths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            paths.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        let p = (url.path as NSString).standardizingPath
                        if !paths.contains(p) { paths.append(p) }
                    }
                } label: {
                    Label("Add Parked Directory…", systemImage: "plus")
                }
            } header: {
                Text("Parked Directories")
                Text("Every subdirectory becomes a Valet site automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Save button
            Section {
                HStack {
                    Button("Save Changes") {
                        saveConfig()
                    }
                    .buttonStyle(.borderedProminent)

                    if let status = saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status.contains("✓") ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadConfig() }
    }

    private func loadConfig() {
        guard let config = ValetConfigReader.readConfig() else { return }
        tld = config.tld
        loopback = config.loopback ?? "127.0.0.1"
        paths = config.paths
        shareTool = "expose" // default — extend ValetConfig if needed
    }

    private func saveConfig() {
        let configPath = ValetConfigReader.configPath
        guard var raw = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              var dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
        else {
            saveStatus = "✗ Could not read config"
            return
        }

        dict["tld"] = tld.trimmingCharacters(in: .whitespaces)
        dict["loopback"] = loopback.trimmingCharacters(in: .whitespaces)
        dict["paths"] = paths
        dict["share-tool"] = shareTool

        guard let newData = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            saveStatus = "✗ Serialization failed"
            return
        }

        do {
            try newData.write(to: URL(fileURLWithPath: configPath))
            saveStatus = "✓ Saved"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveStatus = nil }
        } catch {
            saveStatus = "✗ \(error.localizedDescription)"
        }
    }
}
