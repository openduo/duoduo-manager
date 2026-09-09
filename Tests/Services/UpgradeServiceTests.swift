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

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.2.5",
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            refreshSkills: { "" }
        )

        // `duoduo upgrade` restarts the daemon itself, so Manager no longer
        // issues a second restart (see #13).
        XCTAssertEqual(output, L10n.Upgrade.updated("duoduo 0.2.5 → 0.4.6"))
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
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            refreshSkills: { "" }
        )

        XCTAssertEqual(output, L10n.Upgrade.updated("duoduo 0.4.5 → 0.4.6"))
        XCTAssertEqual(recorder.commands.map(\.executable), ["duoduo"])
        XCTAssertEqual(recorder.commands.map(\.arguments), [["upgrade"]])
    }

    func testDaemonUpgradeDoesNotRestartDaemonSecondTime() async throws {
        // Regression guard for #13: `duoduo upgrade` already restarts the
        // daemon internally, so Manager must not call restart again (it would
        // kill any in-flight turn a second time, without a reason).
        let recorder = CommandRecorder(results: [.success("cli upgraded\n")])
        let service = UpgradeService(runCommand: recorder.runner)

        _ = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.5",
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            refreshSkills: { "" }
        )

        // Only the `duoduo upgrade` command — no `daemon restart`.
        XCTAssertEqual(recorder.commands.map(\.executable), ["duoduo"])
        XCTAssertEqual(recorder.commands.map(\.arguments), [["upgrade"]])
    }

    func testSkillsRefreshRunsWhenDaemonUpdates() async throws {
        let recorder = CommandRecorder(results: [.success("cli upgraded\n")])
        let service = UpgradeService(runCommand: recorder.runner)
        let skillsRecorder = CallRecorder()

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.5",
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            refreshSkills: {
                skillsRecorder.record()
                return "[skills] refreshed\n"
            }
        )

        XCTAssertEqual(skillsRecorder.count, 1)
        XCTAssertEqual(output, L10n.Upgrade.updated("duoduo 0.4.5 → 0.4.6"))
    }

    func testSkillsRefreshSkippedWhenDaemonUpToDate() async throws {
        let recorder = CommandRecorder(results: [.success("channel synced\n")])
        let service = UpgradeService(runCommand: recorder.runner)
        let skillsRecorder = CallRecorder()

        let channel = ChannelInfo(type: "feishu", version: "0.1.0", isRunning: false)
        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.6",
            channels: [channel],
            latestVersions: ["daemon": "0.4.6", "feishu": "0.2.0"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "channel synced\n" },
            startChannel: { _ in "" },
            refreshSkills: {
                skillsRecorder.record()
                return "[skills] refreshed\n"
            }
        )

        // Daemon was already current, so skills must NOT refresh.
        XCTAssertEqual(skillsRecorder.count, 0)
        XCTAssertEqual(output, L10n.Upgrade.updated("\(channel.displayName) 0.1.0 → 0.2.0"))
    }

    func testSkillsRefreshFailureDoesNotAbort() async throws {
        struct Boom: LocalizedError {
            var errorDescription: String? { "boom" }
        }
        let recorder = CommandRecorder(results: [.success("cli upgraded\n")])
        let service = UpgradeService(runCommand: recorder.runner)

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.5",
            channels: [],
            latestVersions: ["daemon": "0.4.6"],
            stopChannel: { _ in "" },
            syncChannel: { _ in "" },
            startChannel: { _ in "" },
            refreshSkills: { throw Boom() }
        )

        // Throwing refreshSkills is swallowed; daemon upgrade result survives
        // with a non-fatal note so the operator can see the skill miss.
        XCTAssertEqual(
            output,
            L10n.Upgrade.updated("duoduo 0.4.5 → 0.4.6") + " " + L10n.Upgrade.skillsFailed
        )
    }

    func testUpgradeReportsProgressAndStopsChannelsBeforeDaemon() async throws {
        let recorder = CommandRecorder(results: [.success("cli upgraded\n")])
        let service = UpgradeService(runCommand: recorder.runner)
        let progress = ProgressRecorder()
        let channel = ChannelInfo(type: "feishu", version: "0.1.0", isRunning: true, pid: "22")

        let output = try await service.upgradeAll(
            daemonInstalledVersion: "0.4.5",
            channels: [channel],
            latestVersions: ["daemon": "0.4.6", "feishu": "0.2.0"],
            stopChannel: { _ in "stopped" },
            syncChannel: { _ in "synced" },
            startChannel: { _ in "started" },
            refreshSkills: { "skills" },
            onProgress: { message, target in
                progress.record(message, target)
            }
        )

        XCTAssertEqual(progress.messages, [
            L10n.Upgrade.stoppingChannel(channel.displayName),
            L10n.Upgrade.updatingDaemon(from: "0.4.5", to: "0.4.6"),
            L10n.Upgrade.updatingChannel(channel.displayName, from: "0.1.0", to: "0.2.0"),
            L10n.Upgrade.startingChannel(channel.displayName),
            L10n.Upgrade.refreshingSkills
        ])
        XCTAssertEqual(progress.targets, [
            .channel("feishu"),
            .daemon,
            .channel("feishu"),
            .channel("feishu"),
            .skills
        ])
        XCTAssertEqual(
            output,
            L10n.Upgrade.updated("duoduo 0.4.5 → 0.4.6, \(channel.displayName) 0.1.0 → 0.2.0")
        )
    }

    func testUpgradeFailureKeepsTheStepInTheError() async throws {
        struct Boom: LocalizedError {
            var errorDescription: String? { "npm 404\nmore noise" }
        }
        let recorder = CommandRecorder(results: [
            .failure(Boom()),
            .failure(Boom())
        ])
        let service = UpgradeService(runCommand: recorder.runner)

        do {
            _ = try await service.upgradeAll(
                daemonInstalledVersion: "0.4.5",
                channels: [],
                latestVersions: ["daemon": "0.4.6"],
                stopChannel: { _ in "" },
                syncChannel: { _ in "" },
                startChannel: { _ in "" },
                refreshSkills: { "" }
            )
            XCTFail("expected throw")
        } catch let error as UpgradeStepError {
            XCTAssertEqual(error.step, L10n.Upgrade.updatingDaemon(from: "0.4.5", to: "0.4.6"))
            XCTAssertEqual(error.reason, "npm 404")
            XCTAssertEqual(
                error.localizedDescription,
                L10n.Upgrade.failedDuring(error.step, "npm 404")
            )
        }
    }

    func testShortReasonTakesFirstLineAndTruncates() {
        let error = ShellError.executionFailed("first line\nsecond line", exitCode: 1)
        XCTAssertEqual(UpgradeService.shortReason(error), "first line")
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(String, UpgradeTarget?)] = []

    var messages: [String] {
        lock.withLock { recorded.map(\.0) }
    }

    var targets: [UpgradeTarget?] {
        lock.withLock { recorded.map(\.1) }
    }

    func record(_ message: String, _ target: UpgradeTarget?) {
        lock.withLock { recorded.append((message, target)) }
    }
}

private extension UpgradeService {
    func upgradeAll(
        daemonInstalledVersion: String,
        channels: [ChannelInfo],
        latestVersions: [String: String],
        stopChannel: @escaping (String) async throws -> String,
        syncChannel: @escaping (String) async throws -> String,
        startChannel: @escaping (String) async throws -> String,
        refreshSkills: @escaping () async throws -> String
    ) async throws -> String {
        try await upgradeAll(
            daemonInstalledVersion: daemonInstalledVersion,
            channels: channels,
            latestVersions: latestVersions,
            stopChannel: stopChannel,
            syncChannel: syncChannel,
            startChannel: startChannel,
            refreshSkills: refreshSkills,
            onProgress: { _, _ in }
        )
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
