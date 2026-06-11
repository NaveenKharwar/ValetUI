import SwiftUI
import AppKit

struct LogViewerView: View {
    let logPath: String

    @State private var content: String = ""
    @State private var autoScroll = true
    @State private var tailTask: Task<Void, Never>?

    private var fileName: String {
        (logPath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(fileName)
                        .font(.headline)
                    Text(logPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
                } label: {
                    Label("Console", systemImage: "arrow.up.forward.app")
                }
                .help("Open in Console.app")
            }
            .padding(10)
            .background(.regularMaterial)

            Divider()

            // Log body
            ScrollViewReader { proxy in
                ScrollView {
                    Text(content.isEmpty ? "Log is empty or file not found." : content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("logEnd")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: content) {
                    if autoScroll {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .onAppear { startTailing() }
        .onDisappear { tailTask?.cancel() }
    }

    private func startTailing() {
        tailTask?.cancel()
        tailTask = Task {
            while !Task.isCancelled {
                content = LogTailer.tail(path: logPath)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
