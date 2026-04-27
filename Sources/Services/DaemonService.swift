import Foundation

final class DaemonService: Sendable {
    let daemonURL: String

    init(daemonURL: String) {
        self.daemonURL = daemonURL
    }

    // MARK: - Daemon Commands

    func getStatus() async throws -> DaemonStatus {
        guard let dir = NodeRuntime.duoduoPackageDir else {
            return DaemonStatus()
        }
        let output = try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["daemon", "status"],
            environment: daemonEnv,
            workingDirectory: dir
        )
        return parseStatusOutput(output)
    }

    func getVersion() async throws -> String {
        guard NodeRuntime.isDuoduoInstalled else { return "" }
        let output = try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["daemon", "status"],
            environment: daemonEnv,
            workingDirectory: NodeRuntime.duoduoPackageDir
        )
        // Match the full semver token, including pre-release suffix
        // (e.g. `0.5.0-rc.1`, `0.5.0-pre.22`). The previous `[\d.]+`
        // pattern silently truncated `-rc.1` / `-pre.22`, which would
        // let pre-releases pass version gates aimed at the released rc.
        if let range = output.range(of: "version: ([\\w.-]+)", options: .regularExpression) {
            return String(output[range]).replacingOccurrences(of: "version: ", with: "")
        }
        return ""
    }

    func start(extraEnv: [String: String] = [:]) async throws -> String {
        guard NodeRuntime.isDuoduoInstalled else {
            return "duoduo not installed"
        }

        var env = daemonEnv
        env.merge(extraEnv) { _, new in new }

        return try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["daemon", "start", "--daemon-url", daemonURL],
            environment: env,
            workingDirectory: NodeRuntime.duoduoPackageDir
        )
    }

    func stop() async throws -> String {
        let output = try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["daemon", "stop"],
            environment: daemonEnv,
            workingDirectory: NodeRuntime.duoduoPackageDir
        )
        return output
    }

    func restart(extraEnv: [String: String] = [:]) async throws -> String {
        guard NodeRuntime.isDuoduoInstalled else {
            return "duoduo not installed"
        }

        var env = daemonEnv
        env.merge(extraEnv) { _, new in new }

        return try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["daemon", "restart", "--daemon-url", daemonURL],
            environment: env,
            workingDirectory: NodeRuntime.duoduoPackageDir
        )
    }

    // MARK: - Environment

    private var daemonEnv: [String: String] {
        var env = NodeRuntime.duoduoSpawnEnv
        env["ALADUO_DAEMON_URL"] = daemonURL
        return env
    }

    // MARK: - Private

    private func parseStatusOutput(_ output: String) -> DaemonStatus {
        var status = DaemonStatus()
        status.output = output
        status.isRunning = output.contains("healthy: yes") || output.contains("pid_alive: yes")
        status.lastUpdated = .now

        if let pidRange = output.range(of: "pid: ([0-9]+)", options: .regularExpression) {
            let pidString = String(output[pidRange])
            status.pid = pidString.replacingOccurrences(of: "pid: ", with: "")
        }
        status.daemonConfigValues = parseConfigValues(output)

        return status
    }

    private func parseConfigValues(_ output: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let parts = rawLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = String(parts[0])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = String(parts[1])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard key == "work_dir", !value.isEmpty else { continue }
            values["ALADUO_WORK_DIR"] = value
        }

        return values
    }
}
