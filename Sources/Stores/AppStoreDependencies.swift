import Foundation

struct AppStoreDependencies {
    var versionService: any VersionServicing
    var upgradeService: any UpgradeServicing
    var runtimeEnvironment: any RuntimeEnvironmentProviding
    var makeDaemonService: @Sendable (String) -> any DaemonServicing
    var makeChannelService: @Sendable (String) -> any ChannelServicing
    var makeDashboardRPCService: @Sendable (String) -> any DashboardRPCServicing

    static let live = AppStoreDependencies(
        versionService: VersionService(),
        upgradeService: UpgradeService(),
        runtimeEnvironment: LiveRuntimeEnvironment(),
        makeDaemonService: { DaemonService(daemonURL: $0) },
        makeChannelService: { ChannelService(daemonURL: $0) },
        makeDashboardRPCService: { DashboardRPCService(daemonURL: $0) }
    )
}
