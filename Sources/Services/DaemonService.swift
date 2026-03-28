import Foundation

final class DaemonService: Sendable {
    let daemonURL: String

    init(daemonURL: String) {
        self.daemonURL = daemonURL
    }

    private var daemonEnv: [String: String] {
        var env: [String: String] = [
            "ALADUO_DAEMON_URL": daemonURL,
        ]
        // Read duoduo config and inject key settings
        if let config = readDuoduoConfig() {
            if let workDir = config["workDir"] as? String {
                env["ALADUO_WORK_DIR"] = workDir
            }
            if let mode = config["mode"] as? String {
                env["ALADUO_RUNTIME_MODE"] = mode
            }
        }
        return env
    }

    private func readDuoduoConfig() -> [String: Any]? {
        let configPath = NSHomeDirectory() + "/.config/duoduo/config.json"
        guard let data = FileManager.default.contents(atPath: configPath) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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
        guard let dir = NodeRuntime.duoduoPackageDir else { return "" }
        let pkgJsonURL = URL(fileURLWithPath: dir).appendingPathComponent("package.json")
        guard let data = FileManager.default.contents(atPath: pkgJsonURL.path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String
        else { return "" }
        return version
    }

    func start(extraEnv: [String: String] = [:]) async throws -> String {
        guard NodeRuntime.isDuoduoInstalled else {
            return "duoduo not installed"
        }

        let env = buildLaunchEnv(extraEnv: extraEnv)
        try await LaunchAgentService.install(environment: env)

        let healthy = await waitForHealthy(timeout: 10)
        if healthy {
            writePidFile()
        }
        return healthy ? "Daemon started via LaunchAgent." : "Daemon plist loaded; check status for startup progress."
    }

    func stop() async throws -> String {
        removePidFile()
        try LaunchAgentService.uninstall()
        return "Daemon stopped."
    }

    func restart(extraEnv: [String: String] = [:]) async throws -> String {
        try LaunchAgentService.uninstall()

        let env = buildLaunchEnv(extraEnv: extraEnv)
        try await LaunchAgentService.install(environment: env)

        let healthy = await waitForHealthy(timeout: 10)
        if healthy {
            writePidFile()
        }
        return healthy ? "Daemon restarted via LaunchAgent." : "Daemon plist reloaded; check status."
    }

    // MARK: - Environment

    private func buildLaunchEnv(extraEnv: [String: String] = [:]) -> [String: String] {
        var merged = NodeRuntime.environment
        merged.merge(daemonEnv) { _, new in new }
        extraEnv.forEach { merged[$0] = $1 }
        return merged
    }

    // MARK: - PID File

    private static var pidFilePath: String {
        "\(NSHomeDirectory())/.aladuo/run/daemon-supervisor.pid.json"
    }

    /// Get PID from launchctl and write PID file so `duoduo daemon status` can find it.
    private func writePidFile() {
        let pid = Self.getPidFromLaunchctl()
        guard let pid else { return }

        let path = Self.pidFilePath
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let json = "{\"pid\":\(pid),\"startedAt\":\"\(timestamp)\"}"
        try? Data(json.utf8).write(to: URL(fileURLWithPath: path))
    }

    private func removePidFile() {
        try? FileManager.default.removeItem(atPath: Self.pidFilePath)
    }

    private static func getPidFromLaunchctl() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: true)
            // launchctl list format: PID\tStatus\tLabel
            if parts.count >= 3,
               parts[2].hasSuffix(LaunchAgentService.label),
               let pid = Int(parts[0]) {
                return pid
            }
        }
        return nil
    }

    // MARK: - Private

    private func waitForHealthy(timeout: TimeInterval = 10) async -> Bool {
        let urlStr = daemonURL.replacingOccurrences(of: "/$", with: "")
        guard let url = URL(string: "\(urlStr)/healthz") else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return true
                }
            } catch { }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
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
