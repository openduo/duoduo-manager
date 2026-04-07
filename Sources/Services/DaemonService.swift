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
        if let range = output.range(of: "version: ([\\d.]+)", options: .regularExpression) {
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
        ["ALADUO_DAEMON_URL": daemonURL]
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

        return status
    }
}
