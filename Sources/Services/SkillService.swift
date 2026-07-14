import Foundation

/// Refreshes the `openduo/duoduo` skills that describe the CLI's behavior surface.
///
/// Skills are installed project-style under `~/aladuo` (Claude Code reads
/// `.claude/skills/`, Codex reads `.agents/skills/`). They are read by new
/// sessions only, so a refresh never needs a daemon restart and can run as the
/// tail step of the CLI upgrade flow.
///
/// See openduo/duoduo-manager#11.
struct SkillService: Sendable {
    /// GitHub source whose `skills/` directory ships the bundled skills.
    static let source = "openduo/duoduo"

    /// Project root the skills CLI installs into. `skills add` has no `--dir`
    /// flag, so the install location is determined by the current working
    /// directory: project-level installs land in `<cwd>/.agents/skills/` and
    /// `<cwd>/.claude/skills/`.
    static let installRoot: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("aladuo").path
    }()

    /// The agents to install for. Scoped to the two duoduo targets rather than
    /// `*` so local-only or externally-sourced skills are never touched.
    static let agents = ["claude-code", "codex"]

    private var installArguments: [String] {
        ["-y", "skills@latest", "add", Self.source, "--skill", "*"]
            + Self.agents.flatMap { ["-a", $0] }
            + ["-y"]
    }

    /// Refresh the bundled skills. Never throws — a failure (network error,
    /// npx noise, etc.) is swallowed and reported as a short note so it never
    /// aborts the surrounding daemon/channel upgrade.
    func refreshSkills() async -> String {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: Self.installRoot, isDirectory: &isDir) || !isDir.boolValue {
            do {
                try fm.createDirectory(atPath: Self.installRoot, withIntermediateDirectories: true)
            } catch {
                return "\n[skills] install root not available, skipped\n"
            }
        }

        do {
            let output = try await ShellService.run(
                "npx",
                arguments: installArguments,
                environment: [:],
                workingDirectory: Self.installRoot
            )
            let summary = parsedSummary(from: output)
            return "\n[skills] refreshed \(Self.source)" + (summary.isEmpty ? "" : " — \(summary)") + "\n"
        } catch {
            return "\n[skills] refresh failed (non-fatal): \(error.localizedDescription)\n"
        }
    }

    // MARK: - Private

    /// Pull a short, human-readable summary out of the skills CLI output
    /// (which is heavily ANSI-painted). We look for the installed skill count.
    private func parsedSummary(from output: String) -> String {
        let cleaned = output.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        // Count "✓ ./.agents/skills/<name>" style lines, or fall back to
        // any "<name>/SKILL.md" mention.
        let installedSkillLines = cleaned
            .split(separator: "\n")
            .filter { $0.contains("✓") && $0.contains("/.agents/skills/") }
        if !installedSkillLines.isEmpty {
            return "\(installedSkillLines.count) skill(s)"
        }
        return ""
    }
}
