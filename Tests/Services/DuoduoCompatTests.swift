import XCTest
@testable import DuoduoManager

final class DuoduoCompatTests: XCTestCase {
    func testMeetsMinimumWithReleaseAboveRC() {
        XCTAssertTrue(DuoduoCompat.meetsMinimum(installed: "0.5.0", minimum: "0.5.0-rc.1"))
    }

    func testMeetsMinimumRejectsOlderPrerelease() {
        XCTAssertFalse(DuoduoCompat.meetsMinimum(installed: "0.5.0-pre.22", minimum: "0.5.0-rc.1"))
    }

    func testMeetsMinimumUsesNumericOrderingWithinPrerelease() {
        XCTAssertTrue(DuoduoCompat.meetsMinimum(installed: "0.5.0-rc.10", minimum: "0.5.0-rc.2"))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(installed: "0.5.0-rc.2", minimum: "0.5.0-rc.10"))
    }

    func testMeetsMinimumRejectsEmptyOrMalformedValues() {
        XCTAssertFalse(DuoduoCompat.meetsMinimum(installed: nil, minimum: "0.5.0-rc.1"))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(installed: "", minimum: "0.5.0-rc.1"))
    }
}
