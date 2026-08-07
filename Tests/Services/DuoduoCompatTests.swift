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

    func testMinVersionForRestartReasonGatesBelowThreshold() {
        // The `--reason` flag on `daemon restart` shipped in v0.7.0; there
        // was no 0.6.x release that carried it (0.6.2 → 0.7.0). Older CLIs
        // reject it as an unknown argument. The gate must pass 0.7.0 and
        // reject everything older, including the never-released 0.6.3 (see #13).
        XCTAssertTrue(DuoduoCompat.meetsMinimum(
            installed: DuoduoCompat.minVersionForRestartReason,
            minimum: DuoduoCompat.minVersionForRestartReason
        ))
        XCTAssertTrue(DuoduoCompat.meetsMinimum(
            installed: "0.7.1",
            minimum: DuoduoCompat.minVersionForRestartReason
        ))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(
            installed: "0.6.2",
            minimum: DuoduoCompat.minVersionForRestartReason
        ))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(
            installed: "0.6.3",
            minimum: DuoduoCompat.minVersionForRestartReason
        ))
    }

    func testMinVersionForUnixSocketGatesBelowThreshold() {
        // The transport rework (unix socket + read-only TCP + remote
        // listener) shipped in v0.7.0; there was no 0.6.x release that
        // carried it (0.6.2 → 0.7.0). The gate must pass 0.7.0 and reject
        // everything older, including the never-released 0.6.3 (see #15).
        XCTAssertTrue(DuoduoCompat.meetsMinimum(
            installed: DuoduoCompat.minVersionForUnixSocket,
            minimum: DuoduoCompat.minVersionForUnixSocket
        ))
        XCTAssertTrue(DuoduoCompat.meetsMinimum(
            installed: "0.7.1",
            minimum: DuoduoCompat.minVersionForUnixSocket
        ))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(
            installed: "0.6.2",
            minimum: DuoduoCompat.minVersionForUnixSocket
        ))
        XCTAssertFalse(DuoduoCompat.meetsMinimum(
            installed: "0.6.3",
            minimum: DuoduoCompat.minVersionForUnixSocket
        ))
    }
}
