import Foundation
import XCTest
@testable import DuoduoManager

final class UpgradeServiceTests: XCTestCase {
    func testDaemonUpgradeFallsBackToNpmInstallWhenCliUpgradeFails() async throws {
        let recorder = CommandRecorder(results: [
            .failure(ShellError.executionFailed("unknown command upgrade", exitCode: 1)),
            .success("npm upgraded\n")
        ])
        let service = UpgradeService(runCommand: recorder.runner)
        let restartRecorder = CallRecorder()

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.2.5",
            daemonWasRunning: true,
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            restartDaemon: {
                restartRecorder.record()
                return "daemon restarted\n"
            }
        )

        XCTAssertEqual(output, "npm upgraded\ndaemon restarted\n")
        XCTAssertEqual(restartRecorder.count, 1)
        XCTAssertEqual(recorder.commands.map(\.executable), ["duoduo", "npm"])
        XCTAssertEqual(recorder.commands.map(\.arguments), [
            ["upgrade"],
            ["install", "-g", "@openduo/duoduo"]
        ])
    }

    func testDaemonUpgradeUsesCliUpgradeWhenAvailable() async throws {
        let recorder = CommandRecorder(results: [
            .success("cli upgraded\n")
        ])
        let service = UpgradeService(runCommand: recorder.runner)

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.5",
            daemonWasRunning: false,
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            restartDaemon: { "daemon restarted\n" }
        )

        XCTAssertEqual(output, "cli upgraded\n")
        XCTAssertEqual(recorder.commands.map(\.executable), ["duoduo"])
        XCTAssertEqual(recorder.commands.map(\.arguments), [["upgrade"]])
    }
}

private final class CommandRecorder: @unchecked Sendable {
    struct Command {
        let executable: String
        let arguments: [String]
    }

    enum Result {
        case success(String)
        case failure(Error)
    }

    private let lock = NSLock()
    private var pendingResults: [Result]
    private var recordedCommands: [Command] = []

    init(results: [Result]) {
        pendingResults = results
    }

    var commands: [Command] {
        lock.withLock { recordedCommands }
    }

    var runner: @Sendable (String, [String], [String: String]) async throws -> String {
        { executable, arguments, environment in
            try await self.run(executable, arguments, environment)
        }
    }

    func run(
        _ executable: String,
        _ arguments: [String],
        _ environment: [String: String]
    ) async throws -> String {
        let result = lock.withLock {
            recordedCommands.append(Command(executable: executable, arguments: arguments))
            return pendingResults.removeFirst()
        }

        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }
}

private final class CallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCount = 0

    var count: Int {
        lock.withLock { recordedCount }
    }

    func record() {
        lock.withLock {
            recordedCount += 1
        }
    }
}
