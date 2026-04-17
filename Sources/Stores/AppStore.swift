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

    let versionService = VersionService()
    let upgradeService = UpgradeService()
    let appUpdateService = AppUpdateService()
    var checkForSparkleUpdate: (() -> Void)?

    var daemonService: DaemonService
    var channelService: ChannelService
    var rpc: DashboardRPCService

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

    init() {
        let config = DaemonConfig.load()
        let feishu = FeishuConfig.load()
        runtime = RuntimeStore(
            status: DaemonStatus.empty,
            channels: [],
            daemonConfig: config,
            feishuConfig: feishu,
            isSettingUp: false
        )
        dashboard = DashboardStore()
        updates = UpdateStore()
        command = CommandStore()
        daemonService = DaemonService(daemonURL: config.daemonURL)
        channelService = ChannelService(daemonURL: config.daemonURL)
        rpc = DashboardRPCService(daemonURL: config.daemonURL)
    }

    func reconfigureConnectionsIfNeeded() {
        let daemonURL = runtime.daemonConfig.daemonURL
        if daemonService.daemonURL != daemonURL {
            daemonService = DaemonService(daemonURL: daemonURL)
            channelService = ChannelService(daemonURL: daemonURL)
            rpc = DashboardRPCService(daemonURL: daemonURL)
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

    var hasAppUpdate: Bool {
        guard let latest = updates.appLatestVersion else { return false }
        return AppUpdateService.currentVersion.compare(latest, options: .numeric) == .orderedAscending
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
