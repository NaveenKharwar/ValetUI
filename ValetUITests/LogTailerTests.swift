import XCTest

final class LogTailerTests: XCTestCase {

    private var tempFile: String!

    override func setUp() {
        super.setUp()
        tempFile = NSTemporaryDirectory() + "valetui-tailer-test-\(UUID().uuidString).log"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempFile)
        super.tearDown()
    }

    func testReturnsLastLines() throws {
        let lines = (1...300).map { "line \($0)" }.joined(separator: "\n")
        try lines.write(toFile: tempFile, atomically: true, encoding: .utf8)

        let result = LogTailer.tail(path: tempFile, maxLines: 50)
        let resultLines = result.components(separatedBy: "\n")
        XCTAssertEqual(resultLines.count, 50)
        XCTAssertEqual(resultLines.last, "line 300")
        XCTAssertEqual(resultLines.first, "line 251")
    }

    func testMissingFileReturnsEmpty() {
        XCTAssertEqual(LogTailer.tail(path: "/nonexistent/file.log"), "")
    }

    func testEmptyFileReturnsEmpty() throws {
        try "".write(toFile: tempFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(LogTailer.tail(path: tempFile), "")
    }

    func testCapsBytesReadFromLargeFile() throws {
        let bigLine = String(repeating: "x", count: 1024)
        let content = (1...1000).map { "\(bigLine) \($0)" }.joined(separator: "\n")
        try content.write(toFile: tempFile, atomically: true, encoding: .utf8)

        // 16KB cap on a ~1MB file — must still get the true last line
        let result = LogTailer.tail(path: tempFile, maxLines: 10, maxBytes: 16 * 1024)
        XCTAssertTrue(result.hasSuffix(" 1000"))
        XCTAssertEqual(result.components(separatedBy: "\n").count, 10)
    }
}
