import XCTest

final class SiteValidationTests: XCTestCase {

    func testAcceptsTypicalNames() {
        XCTAssertTrue(Site.isValidName("my-project"))
        XCTAssertTrue(Site.isValidName("blog2"))
        XCTAssertTrue(Site.isValidName("client_site"))
        XCTAssertTrue(Site.isValidName("sub.domain"))
        XCTAssertTrue(Site.isValidName("UPPER"))
    }

    func testRejectsInjectionCharacters() {
        XCTAssertFalse(Site.isValidName("site`drop`"))      // SQL identifier escape
        XCTAssertFalse(Site.isValidName("site\"quote"))     // AppleScript escape
        XCTAssertFalse(Site.isValidName("site;rm -rf"))     // shell chaining
        XCTAssertFalse(Site.isValidName("site name"))       // whitespace
        XCTAssertFalse(Site.isValidName("site$(cmd)"))      // command substitution
    }

    func testRejectsEmptyAndNonASCII() {
        XCTAssertFalse(Site.isValidName(""))
        XCTAssertFalse(Site.isValidName("café"))
    }

    func testSiteURLReflectsSecuredState() {
        let insecure = Site(name: "demo", path: "/tmp/demo", tld: "test", isSecured: false)
        let secure = Site(name: "demo", path: "/tmp/demo", tld: "test", isSecured: true)
        XCTAssertEqual(insecure.url, "http://demo.test")
        XCTAssertEqual(secure.url, "https://demo.test")
    }
}
