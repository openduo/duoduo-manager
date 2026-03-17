import Foundation

struct ChannelService: Sendable {
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

    // MARK: - Channel Commands

    func getChannelStatus(_ channelType: String) async throws -> ChannelInfo {
        let output = try await runDuoduo("channel", channelType, "status")
        return parseChannelStatus(channelType, output)
    }

    func startChannel(_ channelType: String, extraEnv: [String: String] = [:]) async throws
        -> String
    {
        if extraEnv.isEmpty {
            return try await runDuoduo("channel", channelType, "start")
        }
        var merged = env
        extraEnv.forEach { merged[$0] = $1 }
        return try await ShellService.runShell(
            "duoduo channel \(channelType) start", environment: merged)
    }

    func stopChannel(_ channelType: String) async throws -> String {
        try await runDuoduo("channel", channelType, "stop")
    }

    func upgradeChannel(_ channelType: String) async throws -> String {
        let packageName =
            ChannelRegistry.entry(for: channelType, feishuConfig: FeishuConfig())?.packageName
            ?? "@openduo/channel-\(channelType)"
        let upgradeOutput = try await ShellService.runShell("npm update -g \(packageName)")
        let syncOutput = try await runDuoduo("channel", "install", packageName)
        return upgradeOutput + "\n" + syncOutput
    }

    func installChannel(_ packageName: String) async throws -> String {
        let npmOutput = try await ShellService.runShell("npm install -g \(packageName)")
        let syncOutput = try await runDuoduo("channel", "install", packageName)
        return npmOutput + "\n" + syncOutput
    }

    // MARK: - Private

    private func runDuoduo(_ args: String...) async throws -> String {
        let command = ["duoduo"] + args
        return try await ShellService.runShell(command.joined(separator: " "), environment: env)
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
}
