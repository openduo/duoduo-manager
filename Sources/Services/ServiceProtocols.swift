import Foundation

struct AppReleaseInfo: Sendable, Equatable {
    let version: String
    let url: URL
}

protocol DaemonServicing: Sendable {
    var daemonURL: String { get }
    func getStatus() async throws -> DaemonStatus
    func getVersion() async throws -> String
    func start(extraEnv: [String: String]) async throws -> String
    func stop() async throws -> String
    func restart(extraEnv: [String: String]) async throws -> String
}

protocol ChannelServicing: Sendable {
    var daemonURL: String { get }
    func getChannelStatus(_ channelType: String) async throws -> ChannelInfo
    func startChannel(_ channelType: String, extraEnv: [String: String]) async throws -> String
    func stopChannel(_ channelType: String) async throws -> String
    func upgradeChannel(_ channelType: String) async throws -> String
    func installChannel(_ packageName: String) async throws -> String
    func syncChannel(_ packageName: String) async throws -> String
}

protocol DashboardRPCServicing: Sendable {
    var baseURL: String { get }
    func systemStatus() async throws -> SystemStatus
    func usageTotals() async throws -> UsageTotalsResponse
    func jobList() async throws -> JobListResponse
    func spineTail(afterId: String?, limit: Int) async throws -> SpineTailResponse
    func systemConfig() async throws -> SystemConfig
}

protocol VersionServicing: Sendable {
    func getInstalledVersion(_ pkg: String) async throws -> String?
    func getNpmLatestVersion(_ pkg: String) async throws -> String
}

protocol UpgradeServicing: Sendable {
    func upgradeAll(
        daemonInstalledVersion: String,
        daemonWasRunning: Bool,
        channels: [ChannelInfo],
        latestVersions: [String: String],
        stopChannel: (String) async throws -> String,
        syncChannel: (String) async throws -> String,
        startChannel: (String) async throws -> String,
        restartDaemon: () async throws -> String
    ) async throws -> String
}

protocol AppUpdateServicing: Sendable {
    func fetchLatestReleaseVersion() async -> String?
    func fetchLatestRelease() async -> AppReleaseInfo?
}

protocol RuntimeEnvironmentProviding: Sendable {
    var isDuoduoInstalled: Bool { get }
    var hasBundledNode: Bool { get }
    var hasSystemNode: Bool { get }
    func installDuoduo() async throws -> String
}

struct LiveRuntimeEnvironment: RuntimeEnvironmentProviding {
    var isDuoduoInstalled: Bool { NodeRuntime.isDuoduoInstalled }
    var hasBundledNode: Bool { NodeRuntime.hasBundledNode }
    var hasSystemNode: Bool { NodeRuntime.hasSystemNode }

    func installDuoduo() async throws -> String {
        try await NodeRuntime.installDuoduo()
    }
}

extension DaemonService: DaemonServicing {}
extension ChannelService: ChannelServicing {}
extension DashboardRPCService: DashboardRPCServicing {}
extension VersionService: VersionServicing {}
extension UpgradeService: UpgradeServicing {}
extension AppUpdateService: AppUpdateServicing {}
