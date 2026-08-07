import XCTest
@testable import DuoduoManager

final class DaemonServiceRestartReasonTests: XCTestCase {
    private let url = "http://127.0.0.1:20233"

    func testAppendsReasonWhenCliNewEnough() {
        // Happy path: the running duoduo accepts --reason, so the reason is
        // threaded through verbatim for the woken sessions to read (#13).
        let args = DaemonService.restartArguments(
            daemonURL: url,
            reason: "manual restart from duoduo-manager menubar",
            installedVersion: "0.7.0"
        )
        XCTAssertEqual(args, [
            "daemon", "restart", "--daemon-url", url,
            "--reason", "manual restart from duoduo-manager menubar"
        ])
    }

    func testOmitsReasonWhenCliTooOld() {
        // Older CLIs treat --reason as an unknown argument and fail, so the
        // flag must be dropped entirely below the version gate.
        let args = DaemonService.restartArguments(
            daemonURL: url,
            reason: "manual restart from duoduo-manager menubar",
            installedVersion: "0.6.2"
        )
        XCTAssertEqual(args, ["daemon", "restart", "--daemon-url", url])
    }

    func testOmitsReasonWhenVersionUnknown() {
        // We don't yet know the installed version (e.g. daemon not running).
        // Passing an unknown flag would fail, so be conservative and omit it.
        let args = DaemonService.restartArguments(
            daemonURL: url,
            reason: "manual restart",
            installedVersion: nil
        )
        XCTAssertEqual(args, ["daemon", "restart", "--daemon-url", url])
    }

    func testOmitsReasonWhenBlankOrEmpty() {
        // Whitespace-only / empty reasons carry no signal for a reasoning
        // model, so don't emit the flag even on a new-enough CLI.
        for blank in ["", "   ", "\n\t"] {
            let args = DaemonService.restartArguments(
                daemonURL: url,
                reason: blank,
                installedVersion: "0.7.0"
            )
            XCTAssertEqual(args, ["daemon", "restart", "--daemon-url", url])
        }
    }

    func testTrimsReasonWhitespace() {
        let args = DaemonService.restartArguments(
            daemonURL: url,
            reason: "  upgraded @openduo/duoduo to 0.7.0  ",
            installedVersion: "0.7.0"
        )
        XCTAssertEqual(args.last, "upgraded @openduo/duoduo to 0.7.0")
    }

    func testOmitsReasonWhenNilEvenIfVersionNewEnough() {
        let args = DaemonService.restartArguments(
            daemonURL: url,
            reason: nil,
            installedVersion: "0.7.0"
        )
        XCTAssertEqual(args, ["daemon", "restart", "--daemon-url", url])
    }
}
