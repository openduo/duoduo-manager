import Foundation
@testable import DuoduoManager

struct FakeDaemonService: DaemonServicing {
    let daemonURL: String
    var status: DaemonStatus = .empty
    var version: String = ""
    var startResult = ""
    var stopResult = ""
    var restartResult = ""

    func getStatus() async throws -> DaemonStatus { status }
    func getVersion() async throws -> String { version }
    func start(extraEnv: [String: String]) async throws -> String { startResult }
    func stop() async throws -> String { stopResult }
    func restart(extraEnv: [String: String]) async throws -> String { restartResult }
}

struct FakeChannelService: ChannelServicing {
    let daemonURL: String
    var channelStatuses: [String: ChannelInfo] = [:]
    var startResult = ""
    var stopResult = ""
    var upgradeResult = ""
    var installResult = ""
    var syncResult = ""

    func getChannelStatus(_ channelType: String) async throws -> ChannelInfo {
        guard let info = channelStatuses[channelType] else {
            throw ShellError.executionFailed("missing channel status", exitCode: 1)
        }
        return info
    }

    func startChannel(_ channelType: String, extraEnv: [String: String]) async throws -> String { startResult }
    func stopChannel(_ channelType: String) async throws -> String { stopResult }
    func upgradeChannel(_ channelType: String) async throws -> String { upgradeResult }
    func installChannel(_ packageName: String) async throws -> String { installResult }
    func syncChannel(_ packageName: String) async throws -> String { syncResult }
}

struct FakeDashboardRPCService: DashboardRPCServicing {
    let baseURL: String
    var systemStatusResponse: SystemStatus
    var usageTotalsResponse: UsageTotalsResponse
    var jobListResponse: JobListResponse
    var spineTailResponse: SpineTailResponse
    var systemConfigResponse: SystemConfig

    func systemStatus() async throws -> SystemStatus { systemStatusResponse }
    func usageTotals() async throws -> UsageTotalsResponse { usageTotalsResponse }
    func jobList() async throws -> JobListResponse { jobListResponse }
    func spineTail(afterId: String?, limit: Int) async throws -> SpineTailResponse { spineTailResponse }
    func systemConfig() async throws -> SystemConfig { systemConfigResponse }
}

struct FakeVersionService: VersionServicing {
    var installedVersions: [String: String?] = [:]
    var latestVersions: [String: String] = [:]

    func getInstalledVersion(_ pkg: String) async throws -> String? { installedVersions[pkg] ?? nil }
    func getNpmLatestVersion(_ pkg: String) async throws -> String { latestVersions[pkg] ?? "" }
}

struct FakeUpgradeService: UpgradeServicing {
    var output = ""

    func upgradeAll(
        daemonInstalledVersion: String,
        daemonWasRunning: Bool,
        channels: [ChannelInfo],
        latestVersions: [String: String],
        stopChannel: (String) async throws -> String,
        syncChannel: (String) async throws -> String,
        startChannel: (String) async throws -> String,
        restartDaemon: () async throws -> String
    ) async throws -> String {
        output
    }
}

struct FakeAppUpdateService: AppUpdateServicing {
    var latestRelease: AppReleaseInfo?

    func fetchLatestReleaseVersion() async -> String? { latestRelease?.version }
    func fetchLatestRelease() async -> AppReleaseInfo? { latestRelease }
}

struct FakeRuntimeEnvironment: RuntimeEnvironmentProviding {
    var isDuoduoInstalled = true
    var hasBundledNode = true
    var hasSystemNode = true
    var installResult = ""

    func installDuoduo() async throws -> String { installResult }
}

enum TestFactory {
    static func dependencies(
        daemonStatus: DaemonStatus = .empty,
        daemonVersion: String = "",
        channelStatuses: [String: ChannelInfo] = [:],
        latestVersions: [String: String] = [:],
        latestRelease: AppReleaseInfo? = nil,
        systemStatus: SystemStatus = SystemStatus(sessions: [], health: HealthInfo(gateway: "ok", meta_session: "ok"), subconscious: nil, cadence: nil),
        usageTotals: UsageTotalsResponse = UsageTotalsResponse(totals: UsageTotals(total_cost_usd: 0, total_input_tokens: 0, total_output_tokens: 0, total_cache_read_tokens: 0, total_tool_calls: 0)),
        jobs: JobListResponse = JobListResponse(jobs: []),
        events: SpineTailResponse = SpineTailResponse(events: []),
        config: SystemConfig = SystemConfig(network: nil, sessions: nil, cadence: nil, transfer: nil, logging: nil, sdk: nil, paths: nil, subconscious: nil),
        runtimeEnvironment: any RuntimeEnvironmentProviding = FakeRuntimeEnvironment()
    ) -> AppStoreDependencies {
        AppStoreDependencies(
            versionService: FakeVersionService(latestVersions: latestVersions),
            upgradeService: FakeUpgradeService(),
            appUpdateService: FakeAppUpdateService(latestRelease: latestRelease),
            runtimeEnvironment: runtimeEnvironment,
            makeDaemonService: { url in
                FakeDaemonService(daemonURL: url, status: daemonStatus, version: daemonVersion)
            },
            makeChannelService: { url in
                FakeChannelService(daemonURL: url, channelStatuses: channelStatuses)
            },
            makeDashboardRPCService: { url in
                FakeDashboardRPCService(
                    baseURL: url,
                    systemStatusResponse: systemStatus,
                    usageTotalsResponse: usageTotals,
                    jobListResponse: jobs,
                    spineTailResponse: events,
                    systemConfigResponse: config
                )
            }
        )
    }
}
