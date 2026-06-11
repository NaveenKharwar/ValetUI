import XCTest

final class BrewParserTests: XCTestCase {

    func testParsesVersionedAndDefaultPHP() {
        let output = """
        php
        php@8.1
        php@8.2
        """
        let versions = BrewParser.parsePHPVersions(output)
        XCTAssertEqual(versions.count, 3)
        XCTAssertTrue(versions.contains { $0.brewName == "php" && $0.version == "current" })
        XCTAssertTrue(versions.contains { $0.brewName == "php@8.1" && $0.version == "8.1" })
        XCTAssertTrue(versions.contains { $0.brewName == "php@8.2" && $0.version == "8.2" })
    }

    func testIgnoresNonPHPFormulae() {
        let output = """
        php@8.3
        phpunit
        node
        php@bogus
        """
        let versions = BrewParser.parsePHPVersions(output)
        XCTAssertEqual(versions.map(\.brewName), ["php@8.3"])
    }

    func testEmptyOutputReturnsEmpty() {
        XCTAssertTrue(BrewParser.parsePHPVersions("").isEmpty)
        XCTAssertTrue(BrewParser.parsePHPVersions("   \n  ").isEmpty)
    }

    func testSortsNewestFirst() {
        let versions = BrewParser.parsePHPVersions("php@8.1\nphp@8.3\nphp@8.2")
        XCTAssertEqual(versions.map(\.version), ["8.3", "8.2", "8.1"])
    }

    func testResolveCurrentVersionMarksMatch() {
        var versions = BrewParser.parsePHPVersions("php@8.2\nphp@8.3")
        BrewParser.resolveCurrentVersion(versions: &versions, currentVersionString: "8.2")
        XCTAssertEqual(versions.first { $0.isCurrent }?.version, "8.2")
        XCTAssertEqual(versions.filter(\.isCurrent).count, 1)
    }

    func testResolveCurrentVersionSubstitutesPlaceholder() {
        var versions = BrewParser.parsePHPVersions("php\nphp@8.1")
        BrewParser.resolveCurrentVersion(versions: &versions, currentVersionString: "8.5")
        XCTAssertTrue(versions.contains { $0.brewName == "php" && $0.version == "8.5" && $0.isCurrent })
        XCTAssertFalse(versions.contains { $0.version == "current" })
    }

    // Regression: php (8.5) installed alongside php@8.4 which is linked.
    // The default formula must keep its own version and NOT be marked current.
    func testLinkedVersionedFormulaDoesNotMarkDefaultAsCurrent() {
        var versions = BrewParser.parsePHPVersions("php\nphp@8.4")
        if let i = versions.firstIndex(where: { $0.version == "current" }) {
            versions[i].version = "8.5"   // what the Cellar lookup provides
        }
        BrewParser.resolveCurrentVersion(versions: &versions, currentVersionString: "8.4")
        XCTAssertEqual(versions.filter(\.isCurrent).map(\.brewName), ["php@8.4"])
    }

    func testParseCellarVersion() {
        XCTAssertEqual(BrewParser.parseCellarVersion(["8.5.4"]), "8.5")
        XCTAssertEqual(BrewParser.parseCellarVersion(["8.4.2", "8.5.4"]), "8.5")
        XCTAssertEqual(BrewParser.parseCellarVersion(["9.0.1", "10.1.0"]), "10.1")
        XCTAssertNil(BrewParser.parseCellarVersion([".DS_Store"]))
        XCTAssertNil(BrewParser.parseCellarVersion([]))
    }

    func testResolveCurrentVersionFallsBackToFirst() {
        var versions = BrewParser.parsePHPVersions("php@8.2\nphp@8.3")
        BrewParser.resolveCurrentVersion(versions: &versions, currentVersionString: "7.4")
        XCTAssertEqual(versions.filter(\.isCurrent).count, 1)
        XCTAssertTrue(versions[0].isCurrent)
    }
}
