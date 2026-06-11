import XCTest

final class ServiceParserTests: XCTestCase {

    // Real-world `brew services list` shape
    private let fixture = """
    Name    Status  User File
    dnsmasq started root ~/Library/LaunchAgents/homebrew.mxcl.dnsmasq.plist
    mysql   none
    nginx   started root /Library/LaunchDaemons/homebrew.mxcl.nginx.plist
    php     started naveen ~/Library/LaunchAgents/homebrew.mxcl.php.plist
    php@8.2 stopped
    """

    func testParsesKnownServicesOnly() {
        let services = ServiceParser.parseServices(fixture)
        XCTAssertEqual(services.map(\.name), ["dnsmasq", "nginx", "php", "php@8.2"])
        XCTAssertFalse(services.contains { $0.name == "mysql" })
    }

    func testRunningStateDetection() {
        let services = ServiceParser.parseServices(fixture)
        XCTAssertEqual(services.first { $0.name == "nginx" }?.isRunning, true)
        XCTAssertEqual(services.first { $0.name == "php@8.2" }?.isRunning, false)
    }

    func testSkipsHeaderLine() {
        let services = ServiceParser.parseServices(fixture)
        XCTAssertFalse(services.contains { $0.name.lowercased() == "name" })
    }

    func testDisplayNames() {
        let services = ServiceParser.parseServices(fixture)
        XCTAssertEqual(services.first { $0.name == "nginx" }?.displayName, "Nginx")
        XCTAssertEqual(services.first { $0.name == "dnsmasq" }?.displayName, "DNSMasq")
        XCTAssertEqual(services.first { $0.name == "php@8.2" }?.displayName, "PHP-FPM (php@8.2)")
    }

    func testEmptyOutputReturnsEmpty() {
        XCTAssertTrue(ServiceParser.parseServices("").isEmpty)
    }

    func testErrorStatusIsNotRunning() {
        let services = ServiceParser.parseServices("nginx error 256 root /path")
        XCTAssertEqual(services.first?.isRunning, false)
    }
}
