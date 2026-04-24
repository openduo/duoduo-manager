import Foundation

enum AppStoreSurface: Hashable {
    case popover
    case dashboard
}

@MainActor
@Observable
final class AppStore {
    let runtime: RuntimeStore
    let dashboard: DashboardStore
    let updates: UpdateStore
    let command: CommandStore

    let dependencies: AppStoreDependencies
    let versionService: any VersionServicing
    let upgradeService: any UpgradeServicing
    let runtimeEnvironment: any RuntimeEnvironmentProviding
    var checkForSparkleUpdate: (() -> Void)?
    var checkForSparkleUpdateSilently: (() -> Void)?

    var daemonService: any DaemonServicing
    var channelService: any ChannelServicing
    var rpc: any DashboardRPCServicing

    var runtimeRefreshTask: Task<Void, Never>?
    var dashboardEventsTask: Task<Void, Never>?
    var dashboardStatusTask: Task<Void, Never>?
    var prepareInteractiveSessionTask: Task<Void, Never>?
    var clearCommandFeedbackTask: Task<Void, Never>?

    var visibleSurfaces: Set<AppStoreSurface> = []
    var lastEventId: String?
    var lastSeenBySession: [String: Date] = [:]
    var hasPreparedInteractiveSession = false

    let maxEvents = 2000
    let runtimeRefreshInterval: TimeInterval = 30
    let dashboardEventsInterval: TimeInterval = 3
    let dashboardStatusInterval: TimeInterval = 5

    var updateStatusBarIcon: (() -> Void)?

    init(
        runtime: RuntimeStore? = nil,
        dashboard: DashboardStore? = nil,
        updates: UpdateStore? = nil,
        command: CommandStore? = nil,
        dependencies: AppStoreDependencies = .live
    ) {
        let runtimeStore = runtime ?? RuntimeStore(
            status: DaemonStatus.empty,
            channels: [],
            daemonConfig: DaemonConfig.load(),
            feishuConfig: FeishuConfig.load(),
            isSettingUp: false
        )
        self.runtime = runtimeStore
        self.dashboard = dashboard ?? DashboardStore()
        self.updates = updates ?? UpdateStore()
        self.command = command ?? CommandStore()
        self.dependencies = dependencies
        versionService = dependencies.versionService
        upgradeService = dependencies.upgradeService
        runtimeEnvironment = dependencies.runtimeEnvironment
        daemonService = dependencies.makeDaemonService(runtimeStore.daemonConfig.daemonURL)
        channelService = dependencies.makeChannelService(runtimeStore.daemonConfig.daemonURL)
        rpc = dependencies.makeDashboardRPCService(runtimeStore.daemonConfig.daemonURL)
    }

    func reconfigureConnectionsIfNeeded() {
        let daemonURL = runtime.daemonConfig.daemonURL
        if daemonService.daemonURL != daemonURL {
            daemonService = dependencies.makeDaemonService(daemonURL)
            channelService = dependencies.makeChannelService(daemonURL)
            rpc = dependencies.makeDashboardRPCService(daemonURL)
            lastEventId = nil
            lastSeenBySession.removeAll()
            dashboard.events.removeAll()
        }
    }

    func hasUpdate(type: String, installedVersion: String) -> Bool {
        guard !installedVersion.isEmpty,
              let latest = updates.latestVersions[type], !latest.isEmpty
        else { return false }
        return installedVersion.compare(latest, options: .numeric) == .orderedAscending
    }

    var hasDuoduoUpdate: Bool {
        hasUpdate(type: "daemon", installedVersion: runtime.status.version)
            || runtime.channels.contains { hasUpdate(type: $0.type, installedVersion: $0.version) }
    }

    static let currentVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }()

    var hasAppUpdate: Bool {
        guard let latest = updates.appLatestVersion else { return false }
        return Self.currentVersion.compare(latest, options: .numeric) == .orderedAscending
    }

    func isJobRunning(_ jobId: String) -> Bool {
        let staleThreshold = TimeInterval(2 * 60)
        let now = Date()
        for (key, ts) in lastSeenBySession where key == "job:\(jobId)" || key.hasPrefix("job:\(jobId).") {
            if now.timeIntervalSince(ts) < staleThreshold {
                return true
            }
        }
        return false
    }
}
