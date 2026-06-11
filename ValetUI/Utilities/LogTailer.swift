import Foundation

enum LogTailer {

    /// Last `maxLines` lines of a file, reading at most `maxBytes` from the end —
    /// avoids loading multi-hundred-MB logs into memory.
    static func tail(path: String, maxLines: Int = 200, maxBytes: Int = 256 * 1024) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return ""
        }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd(), size > 0 else { return "" }

        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }

        var lines = text.components(separatedBy: .newlines)
        // Drop the first line when we started mid-file — it's likely partial
        if offset > 0 && lines.count > 1 {
            lines.removeFirst()
        }
        return lines.suffix(maxLines).joined(separator: "\n")
    }
}
