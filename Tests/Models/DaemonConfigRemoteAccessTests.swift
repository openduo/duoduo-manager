import XCTest
@testable import DuoduoManager

final class DaemonConfigRemoteAccessTests: XCTestCase {
    // MARK: - isNonLoopbackHost

    func testIsNonLoopbackHostFalseForLoopbackValues() {
        for host in ["127.0.0.1", "localhost", "::1", "  127.0.0.1  ", "LOCALHOST"] {
            var config = DaemonConfig()
            config.daemonHost = host
            XCTAssertFalse(config.isNonLoopbackHost, "expected loopback for \(host)")
        }
    }

    func testIsNonLoopbackHostTrueForRemoteValues() {
        for host in ["0.0.0.0", "192.168.1.5", "10.0.0.1", "example.com"] {
            var config = DaemonConfig()
            config.daemonHost = host
            XCTAssertTrue(config.isNonLoopbackHost, "expected non-loopback for \(host)")
        }
    }

    func testIsNonLoopbackHostFalseForEmpty() {
        var config = DaemonConfig()
        config.daemonHost = ""
        XCTAssertFalse(config.isNonLoopbackHost)
    }

    // MARK: - hasRemotePortCollision

    func testHasRemotePortCollisionWhenEqual() {
        var config = DaemonConfig()
        config.port = "20233"
        config.remotePort = "20233"
        XCTAssertTrue(config.hasRemotePortCollision)
    }

    func testHasRemotePortCollisionFalseWhenDistinct() {
        var config = DaemonConfig()
        config.port = "20233"
        config.remotePort = "20234"
        XCTAssertFalse(config.hasRemotePortCollision)
    }

    func testHasRemotePortCollisionFalseWhenRemoteUnset() {
        var config = DaemonConfig()
        config.port = "20233"
        config.remotePort = ""
        XCTAssertFalse(config.hasRemotePortCollision)
    }

    // MARK: - persistedEntries round-trip for ALADUO_REMOTE_PORT

    func testRemotePortPersistedOnlyWhenNonEmpty() {
        var config = DaemonConfig()
        config.remotePort = "20333"
        let keys = config.persistedEntries.map(\.key)
        XCTAssertTrue(keys.contains("ALADUO_REMOTE_PORT"))
        XCTAssertEqual(config.persistedEntries.first(where: { $0.key == "ALADUO_REMOTE_PORT" })?.value, "20333")
    }

    func testRemotePortOmittedWhenEmpty() {
        let config = DaemonConfig()
        XCTAssertFalse(config.persistedEntries.map(\.key).contains("ALADUO_REMOTE_PORT"))
    }
}
