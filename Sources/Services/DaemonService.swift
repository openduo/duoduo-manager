import Foundation

final class DaemonService: Sendable {
    let daemonURL: String

    init(daemonURL: String = "http://127.0.0.1:20233") {
        self.daemonURL = daemonURL
    }

    private var env: [String: String] {
        [
            "ALADUO_DAEMON_URL": daemonURL,
            "ALADUO_LOG_LEVEL": "debug",
        ]
    }

    // MARK: - Package Directory

    /// Resolve the duoduo npm package root via `which duoduo`.
    private func getPackageDir() async throws -> String {
        try await ShellService.runShell(
            "dirname $(dirname $(realpath $(which duoduo)))"
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Daemon Commands

    func getStatus() async throws -> DaemonStatus {
        let dir = try await getPackageDir()
        let output = try await runDuoduo("daemon", "status", workingDirectory: dir)
        return parseStatusOutput(output)
    }

    func getVersion() async throws -> String {
        let dir = try await getPackageDir()
        let output = try await ShellService.runShell(
            "grep '\"version\"' \"\(dir)/package.json\" | head -1 | sed 's/.*\"version\": \"\\([^\"]*\\)\".*/\\1/'"
        )
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard version.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) != nil else {
            return ""
        }
        return version
    }

    func start(extraEnv: [String: String] = [:]) async throws -> String {
        let dir = try await getPackageDir()
        if extraEnv.isEmpty {
            return try await runDuoduo("daemon", "start", workingDirectory: dir)
        }
        var merged = env
        extraEnv.forEach { merged[$0] = $1 }
        return try await ShellService.runShell(
            "duoduo daemon start", environment: merged, workingDirectory: dir
        )
    }

    func stop() async throws -> String {
        let dir = try await getPackageDir()
        _ = try await runDuoduo("daemon", "stop", workingDirectory: dir)
        return ""
    }

    func restart(extraEnv: [String: String] = [:]) async throws -> String {
        let stopOutput = try await stop()
        let startOutput = try await start(extraEnv: extraEnv)
        return stopOutput + "\n" + startOutput
    }

    // MARK: - Private

    private func runDuoduo(_ args: String..., workingDirectory: String = "") async throws -> String {
        let command = ["duoduo"] + args
        return try await ShellService.runShell(
            command.joined(separator: " "), environment: env, workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory
        )
    }

    private func parseStatusOutput(_ output: String) -> DaemonStatus {
        var status = DaemonStatus()
        status.output = output
        status.isRunning = output.contains("healthy: yes") || output.contains("pid_alive: yes")
        status.lastUpdated = .now

        // Parse PID
        if let pidRange = output.range(of: "pid: ([0-9]+)", options: .regularExpression) {
            let pidString = String(output[pidRange])
            status.pid = pidString.replacingOccurrences(of: "pid: ", with: "")
        }

        return status
    }
}
