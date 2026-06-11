import XCTest

final class WPConfigServiceTests: XCTestCase {

    private let stopMarker = "/* That's all, stop editing! Happy publishing. */"

    private func sampleConfig(extra: String = "") -> String {
        """
        <?php
        define( 'DB_NAME', 'mysite' );
        define( 'DB_USER', 'root' );
        \(extra)
        \(stopMarker)
        require_once ABSPATH . 'wp-settings.php';
        """
    }

    // MARK: - detectURLMode

    func testDetectsHardcodedHome() {
        let config = sampleConfig(extra: "define( 'WP_HOME', 'https://mysite.test' );")
        guard case .hardcoded(let home, _) = WPConfigService.detectURLMode(in: config) else {
            return XCTFail("Expected .hardcoded")
        }
        XCTAssertEqual(home, "https://mysite.test")
    }

    func testDetectsDynamic() {
        let config = sampleConfig(extra: "define( 'WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] );")
        guard case .dynamic = WPConfigService.detectURLMode(in: config) else {
            return XCTFail("Expected .dynamic")
        }
    }

    func testDetectsNotDefined() {
        guard case .notDefined = WPConfigService.detectURLMode(in: sampleConfig()) else {
            return XCTFail("Expected .notDefined")
        }
    }

    // MARK: - patchedContent

    func testPatchInsertsBeforeStopMarker() throws {
        let patched = try XCTUnwrap(
            WPConfigService.patchedContent(sampleConfig(), mainDomain: "https://mysite.test")
        )
        let blockIndex = try XCTUnwrap(patched.range(of: "$_SERVER['HTTP_HOST']")).lowerBound
        let markerIndex = try XCTUnwrap(patched.range(of: stopMarker)).lowerBound
        XCTAssertLessThan(blockIndex, markerIndex, "Dynamic block must land before the stop-editing marker")
        XCTAssertTrue(patched.contains("'https://mysite.test'"), "wp-cli fallback uses main domain")
    }

    func testPatchRemovesHardcodedDefines() throws {
        let config = sampleConfig(extra: """
        define( 'WP_HOME', 'https://old.test' );
        define( 'WP_SITEURL', 'https://old.test' );
        """)
        // mainDomain differs from the old value so the inserted wp-cli fallback
        // can't collide with these assertions
        let patched = try XCTUnwrap(
            WPConfigService.patchedContent(config, mainDomain: "https://main.test")
        )
        XCTAssertFalse(patched.contains("'https://old.test'"))
        XCTAssertTrue(patched.contains("$_SERVER['HTTP_HOST']"))
        XCTAssertTrue(patched.contains("'https://main.test'"))
    }

    func testPatchIsNilWhenAlreadyDynamic() {
        let config = sampleConfig(extra: "define( 'WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] );")
        XCTAssertNil(WPConfigService.patchedContent(config, mainDomain: "https://x.test"))
    }

    func testPatchAppendsWhenNoMarkerExists() throws {
        let config = "<?php\ndefine( 'DB_NAME', 'x' );\n"
        let patched = try XCTUnwrap(
            WPConfigService.patchedContent(config, mainDomain: "https://x.test")
        )
        XCTAssertTrue(patched.contains("$_SERVER['HTTP_HOST']"))
        XCTAssertTrue(patched.contains("define( 'DB_NAME', 'x' );"))
    }

    func testPatchPreservesUnrelatedContent() throws {
        let patched = try XCTUnwrap(
            WPConfigService.patchedContent(sampleConfig(), mainDomain: "https://mysite.test")
        )
        XCTAssertTrue(patched.contains("define( 'DB_NAME', 'mysite' );"))
        XCTAssertTrue(patched.contains("require_once ABSPATH . 'wp-settings.php';"))
    }
}
