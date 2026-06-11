import XCTest

final class ValetParserTests: XCTestCase {

    // MARK: - parseCurrentPHP

    func testParsesCurrentPHPFromVersionOutput() {
        let output = "PHP 8.3.4 (cli) (built: Mar 13 2024 12:00:00) (NTS)\nCopyright (c) The PHP Group"
        XCTAssertEqual(ValetParser.parseCurrentPHP(output), "8.3")
    }

    func testParseCurrentPHPRejectsGarbage() {
        XCTAssertNil(ValetParser.parseCurrentPHP("command not found: php"))
        XCTAssertNil(ValetParser.parseCurrentPHP(""))
    }

    // MARK: - parseStatus

    func testParseStatusRunning() {
        XCTAssertEqual(ValetParser.parseStatus("Nginx is running\nPHP is running"), .running)
    }

    func testParseStatusStopped() {
        XCTAssertEqual(ValetParser.parseStatus("Valet is not running"), .stopped)
    }

    func testParseStatusUnknown() {
        XCTAssertEqual(ValetParser.parseStatus("garbage"), .unknown)
    }

    // MARK: - parseLinks

    func testParsesLinkLines() {
        let output = """
        Name    Path
        myblog  /Users/dev/Sites/myblog
        shop    /Users/dev/Sites/shop
        """
        let sites = ValetParser.parseLinks(output, tld: "test")
        XCTAssertEqual(sites.count, 2)
        XCTAssertEqual(sites[0].name, "myblog")
        XCTAssertEqual(sites[0].path, "/Users/dev/Sites/myblog")
        XCTAssertEqual(sites[0].url, "http://myblog.test")
        XCTAssertFalse(sites[0].isParked)
    }

    func testParseLinksEmptyOutput() {
        XCTAssertTrue(ValetParser.parseLinks("").isEmpty)
    }

    // MARK: - parseTLD

    func testParseTLD() {
        XCTAssertEqual(ValetParser.parseTLD("test\n"), "test")
        XCTAssertEqual(ValetParser.parseTLD("  dev "), "dev")
        XCTAssertEqual(ValetParser.parseTLD(""), "test")
    }
}
