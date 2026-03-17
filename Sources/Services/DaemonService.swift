import Foundation

struct DaemonService: Sendable {
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

    // MARK: - Daemon Commands

    func getStatus() async throws -> DaemonStatus {
        let output = try await runDuoduo("daemon", "status")
        return parseStatusOutput(output)
    }

    func getVersion() async throws -> String {
        // Locate package.json via duoduo binary path, avoiding npm list failures
        // caused by incomplete PATH in GUI processes
        let output = try await ShellService.runShell(
            "PKG=$(dirname $(which duoduo))/../lib/node_modules/@openduo/duoduo/package.json && "
            + "grep '\"version\"' \"$PKG\" | head -1 | sed 's/.*\"version\": \"\\([^\"]*\\)\".*/\\1/'"
        )
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validate version format (e.g. 0.3.0)
        guard version.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) != nil else {
            return ""
        }
        return version
    }

    func start(extraEnv: [String: String] = [:]) async throws -> String {
        if extraEnv.isEmpty {
            return try await runDuoduo("daemon", "start")
        }
        var merged = env
        extraEnv.forEach { merged[$0] = $1 }
        return try await ShellService.runShell("duoduo daemon start", environment: merged)
    }

    func stop() async throws -> String {
        try await runDuoduo("daemon", "stop")
    }

    func restart(extraEnv: [String: String] = [:]) async throws -> String {
        let stopOutput = try await stop()
        let startOutput = try await start(extraEnv: extraEnv)
        return stopOutput + "\n" + startOutput
    }

    // MARK: - Private

    private func runDuoduo(_ args: String...) async throws -> String {
        let command = ["duoduo"] + args
        return try await ShellService.runShell(command.joined(separator: " "), environment: env)
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
