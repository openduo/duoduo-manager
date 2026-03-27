import Foundation

struct ChannelService: Sendable {
    let daemonURL: String

    init(daemonURL: String) {
        self.daemonURL = daemonURL
    }

    private var env: [String: String] {
        [
            "ALADUO_DAEMON_URL": daemonURL,
            "ALADUO_LOG_LEVEL": "debug",
        ]
    }

    // MARK: - Channel Commands

    func getChannelStatus(_ channelType: String) async throws -> ChannelInfo {
        let output = try await runDuoduo(["channel", channelType, "status"])
        if isChannelNotInstalled(output, channelType: channelType) {
            throw ShellError.executionFailed(output, exitCode: 0)
        }
        return parseChannelStatus(channelType, output)
    }

    func startChannel(_ channelType: String, extraEnv: [String: String] = [:]) async throws -> String {
        var merged = env
        extraEnv.forEach { merged[$0] = $1 }
        return try await runDuoduo(["channel", channelType, "start"], environment: merged)
    }

    func stopChannel(_ channelType: String) async throws -> String {
        try await runDuoduo(["channel", channelType, "stop"])
    }

    func upgradeChannel(_ channelType: String) async throws -> String {
        let packageName =
            ChannelRegistry.entry(for: channelType, feishuConfig: FeishuConfig())?.packageName
            ?? "@openduo/channel-\(channelType)"
        return try await runDuoduo(["channel", "install", packageName])
    }

    func installChannel(_ packageName: String) async throws -> String {
        try await runDuoduo(["channel", "install", packageName])
    }

    func syncChannel(_ packageName: String) async throws -> String {
        try await runDuoduo(["channel", "install", packageName])
    }

    // MARK: - Private

    private func runDuoduo(_ arguments: [String], environment: [String: String] = [:]) async throws -> String {
        try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: arguments,
            environment: env.merging(environment) { _, new in new }
        )
    }

    private func parseChannelStatus(_ channelType: String, _ output: String) -> ChannelInfo {
        var info = ChannelInfo(type: channelType, version: "", isRunning: false)
        info.isRunning = output.contains("running")

        if let versionRange = output.range(
            of: "@openduo/channel-\(channelType)@([0-9.]+)", options: .regularExpression)
        {
            let versionString = String(output[versionRange])
            if let versionNum = versionString.components(separatedBy: "@").last {
                info.version = versionNum
            }
        }

        if let pidRange = output.range(of: "pid: ([0-9]+)", options: .regularExpression) {
            let pidString = String(output[pidRange])
            info.pid = pidString.replacingOccurrences(of: "pid: ", with: "")
        }

        return info
    }

    private func isChannelNotInstalled(_ output: String, channelType: String) -> Bool {
        let lower = output.lowercased()
        let type = channelType.lowercased()
        return lower.contains("(no channel plugins installed)")
            || lower.contains("\(type): not installed")
            || lower.contains("\(type) not installed")
            || lower.contains("channel not installed")
    }
}
