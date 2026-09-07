import XCTest
@testable import DuoduoManager

final class SkillServiceTests: XCTestCase {
    func testRefreshTargetsGlobalClaudeViaSkillsCLI() async throws {
        let recorder = CommandRecorder()
        recorder.result = .success("✓ ~/.claude/skills/smart-compaction\n")
        let service = SkillService(runCommand: recorder.runner)

        let output = try await service.refreshSkills()

        XCTAssertEqual(recorder.commands.map(\.executable), ["npx"])
        let command = try XCTUnwrap(recorder.commands.first)
        XCTAssertEqual(command.arguments, [
            "-y", "skills@latest", "add", "openduo/duoduo",
            "--skill", "*",
            "--global",
            "--agent", "claude-code",
            "-y"
        ])
        XCTAssertFalse(command.arguments.contains("aladuo"))
        XCTAssertFalse(command.arguments.contains("codex"))
        XCTAssertTrue(output.contains("~/.claude/skills"))
        XCTAssertTrue(output.contains("1 skill(s)"))
    }

    func testParsedSummaryCountsOnlyClaudeUserPaths() {
        let service = SkillService(runCommand: { _, _ in "" })
        let mixed = """
        ✓ ~/.claude/skills/smart-compaction
        ✓ ~/.agents/skills/smart-compaction
        ✓ ~/.codex/skills/smart-compaction
        ✓ ~/.claude/skills/tool-allowlist
        """
        XCTAssertEqual(service.parsedSummary(from: mixed), "2 skill(s)")
    }

    func testParsedSummaryIgnoresAgentsOnlyInstall() {
        let service = SkillService(runCommand: { _, _ in "" })
        let output = """
        ✓ ~/.agents/skills/smart-compaction
        """
        XCTAssertEqual(service.parsedSummary(from: output), "")
    }

    func testRefreshThrowsOnCommandFailure() async {
        let recorder = CommandRecorder()
        recorder.result = .failure(ShellError.executionFailed("npx failed", exitCode: 1))
        let service = SkillService(runCommand: recorder.runner)

        do {
            _ = try await service.refreshSkills()
            XCTFail("expected refreshSkills to throw")
        } catch {
            // Expected: manual install surfaces the npx failure.
        }
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

    var result: Result = .success("")
    private let lock = NSLock()
    private var recorded: [Command] = []

    var commands: [Command] {
        lock.withLock { recorded }
    }

    var runner: @Sendable (String, [String]) async throws -> String {
        { executable, arguments in
            try await self.run(executable, arguments)
        }
    }

    func run(_ executable: String, _ arguments: [String]) async throws -> String {
        let captured = lock.withLock { () -> Result in
            recorded.append(Command(executable: executable, arguments: arguments))
            return result
        }
        switch captured {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }
}
