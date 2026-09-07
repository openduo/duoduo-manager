import Foundation

/// Installs and refreshes the `openduo/duoduo` skills that describe the CLI's
/// behavior surface.
///
/// Duoduo sessions load user skills through the Claude Agent SDK
/// (`settingSources: user`), which reads `~/.claude/skills/`. The skills CLI
/// owns that layout: `--global --agent claude-code` installs into the Claude
/// user directory (canonical store plus the agent link). Manager only invokes
/// the CLI — it does not create directories or rewrite skill trees.
///
/// Skills are read by new sessions only, so a refresh never needs a daemon
/// restart. It runs as the tail step of the CLI upgrade flow and as a
/// manual Control Plane action.
///
/// See openduo/duoduo-manager#11.
struct SkillService: Sendable {
    /// GitHub source whose `skills/` directory ships the bundled skills.
    static let source = "openduo/duoduo"

    /// Claude Code is the agent duoduo sessions actually load skills from.
    static let agent = "claude-code"

    private let runCommand: @Sendable (String, [String]) async throws -> String

    init(
        runCommand: @escaping @Sendable (String, [String]) async throws -> String = {
            executable, arguments in
            try await ShellService.run(
                executable,
                arguments: arguments,
                environment: [:]
            )
        }
    ) {
        self.runCommand = runCommand
    }

    var installArguments: [String] {
        [
            "-y", "skills@latest", "add", Self.source,
            "--skill", "*",
            "--global",
            "--agent", Self.agent,
            "-y"
        ]
    }

    /// Refresh the bundled skills into the Claude user-level directory.
    /// Throws on command failure so a manual install can surface the error;
    /// the upgrade and first-install flows catch and treat it as non-fatal.
    func refreshSkills() async throws -> String {
        let output = try await runCommand("npx", installArguments)
        let summary = parsedSummary(from: output)
        var line = "\n[skills] refreshed \(Self.source) → ~/.claude/skills"
        if !summary.isEmpty {
            line += " — \(summary)"
        }
        return line + "\n"
    }

    /// Pull a short, human-readable summary out of the skills CLI output
    /// (which is heavily ANSI-painted). Count only Claude user-level paths —
    /// that is the directory duoduo actually loads.
    func parsedSummary(from output: String) -> String {
        let cleaned = output.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        let installedSkillLines = cleaned
            .split(separator: "\n")
            .filter { $0.contains("✓") && $0.contains("/.claude/skills/") }
        if !installedSkillLines.isEmpty {
            return "\(installedSkillLines.count) skill(s)"
        }
        return ""
    }
}
