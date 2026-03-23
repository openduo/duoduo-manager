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

    // MARK: - Daemon Commands

    func getStatus() async throws -> DaemonStatus {
        guard let dir = NodeRuntime.duoduoPackageDir else {
            return DaemonStatus()
        }
        let output = try await runDuoduo(["daemon", "status"], workingDirectory: dir)
        return parseStatusOutput(output)
    }

    func getVersion() async throws -> String {
        guard let dir = NodeRuntime.duoduoPackageDir else { return "" }
        let pkgJsonURL = URL(fileURLWithPath: dir).appendingPathComponent("package.json")
        guard let data = FileManager.default.contents(atPath: pkgJsonURL.path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String
        else { return "" }
        return version
    }

    func start(extraEnv: [String: String] = [:]) async throws -> String {
        guard let dir = NodeRuntime.duoduoPackageDir else {
            return "duoduo not installed"
        }
        var merged = env
        extraEnv.forEach { merged[$0] = $1 }
        return try await runDuoduo(["daemon", "start"], environment: merged, workingDirectory: dir)
    }

    func stop() async throws -> String {
        guard let dir = NodeRuntime.duoduoPackageDir else {
            return ""
        }
        return try await runDuoduo(["daemon", "stop"], workingDirectory: dir)
    }

    func restart(extraEnv: [String: String] = [:]) async throws -> String {
        let stopOutput = try await stop()
        let startOutput = try await start(extraEnv: extraEnv)
        return stopOutput + "\n" + startOutput
    }

    // MARK: - Private

    private func runDuoduo(_ arguments: [String], environment: [String: String] = [:], workingDirectory: String? = nil) async throws -> String {
        try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: arguments,
            environment: environment.merging(env) { _, new in new },
            workingDirectory: workingDirectory
        )
    }

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
