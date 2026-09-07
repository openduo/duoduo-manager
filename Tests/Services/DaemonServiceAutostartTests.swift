import XCTest
@testable import DuoduoManager

final class DaemonServiceAutostartTests: XCTestCase {
    func testMissingPlistMeansAutostartDisabled() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-ai.openduo.daemon.plist")
        XCTAssertFalse(DaemonService.isAutostartEnabled(at: url))
    }

    func testRunAtLoadTrueMeansAutostartEnabled() throws {
        let url = try writePlist(runAtLoad: true)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(DaemonService.isAutostartEnabled(at: url))
    }

    func testRunAtLoadFalseMeansAutostartDisabled() throws {
        let url = try writePlist(runAtLoad: false)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertFalse(DaemonService.isAutostartEnabled(at: url))
    }

    private func writePlist(runAtLoad: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai.openduo.daemon-\(UUID().uuidString).plist")
        let plist: [String: Any] = [
            "Label": "ai.openduo.daemon",
            "RunAtLoad": runAtLoad
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
        return url
    }
}
