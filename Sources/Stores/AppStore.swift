import Foundation

struct RuntimeState {
    var status = DaemonStatus.empty
    var channels: [ChannelInfo] = []
    var daemonConfig = DaemonConfig.load()
    var feishuConfig = FeishuConfig.load()
    var isSettingUp = false
}

struct DashboardState {
    var sessions: [SessionInfo] = []
    var health: HealthInfo?
    var subconscious: SubconsciousInfo?
    var cadence: CadenceInfo?
    var jobs: [JobInfo] = []
    var events: [SpineEvent] = []
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var totalTools: Int = 0
    var cacheHitRate: Int = 0
    var config: SystemConfig?
}

struct UpdateState {
    var latestVersions: [String: String] = [:]
    var appLatestVersion: String?
    var appLatestReleaseURL: URL?
}

struct CommandState {
    var isLoading = false
    var lastOutput = ""
    var errorMessage: String?
}

@MainActor
@Observable
final class AppStore {
    private(set) var runtime = RuntimeState()
    private(set) var dashboard = DashboardState()
    private(set) var updates = UpdateState()
    private(set) var command = CommandState()

    private let versionService = VersionService()
    private let upgradeService = UpgradeService()
    private let appUpdateService = AppUpdateService()

    private var daemonService: DaemonService
    private var channelService: ChannelService
    private var rpc: DashboardRPCService

    private var runtimeRefreshTask: Task<Void, Never>?
    private var dashboardEventsTask: Task<Void, Never>?
    private var dashboardStatusTask: Task<Void, Never>?
    private var lastEventId: String?
    private var lastSeenBySession: [String: Date] = [:]

    private let maxEvents = 2000
    var updateStatusBarIcon: (() -> Void)?

    init() {
        let config = DaemonConfig.load()
        let feishu = FeishuConfig.load()
        runtime = RuntimeState(
            status: DaemonStatus.empty,
            channels: [],
            daemonConfig: config,
            feishuConfig: feishu,
            isSettingUp: false
        )
        dashboard = DashboardState()
        updates = UpdateState()
        command = CommandState()
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

    func updateDaemonConfig(_ config: DaemonConfig) {
        runtime.daemonConfig = config
        reconfigureConnectionsIfNeeded()
    }

    func updateFeishuConfig(_ config: FeishuConfig) {
        runtime.feishuConfig = config
    }

    // MARK: - Derived

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

    // MARK: - Setup

    func ensureDuoduoInstalled() async {
        guard !NodeRuntime.isDuoduoInstalled else { return }
        guard NodeRuntime.hasBundledNode || NodeRuntime.hasSystemNode else {
            command.lastOutput = L10n.Setup.systemNodeMissing
            command.errorMessage = L10n.Setup.systemNodeMissingTitle
            return
        }
        runtime.isSettingUp = true
        command.lastOutput = L10n.Setup.installingDuoduo
        do {
            let output = try await NodeRuntime.installDuoduo()
            if NodeRuntime.isDuoduoInstalled {
                command.lastOutput = L10n.Setup.installSuccess
            } else {
                command.lastOutput = L10n.Setup.installFailed + "\n" + output
                command.errorMessage = L10n.Setup.installFailed
            }
        } catch {
            command.lastOutput = L10n.Error.prefix(error.localizedDescription)
            command.errorMessage = error.localizedDescription
        }
        runtime.isSettingUp = false
        updateStatusBarIcon?()
    }

    // MARK: - Polling

    func beginPeriodicRefresh(interval: TimeInterval = 30) {
        runtimeRefreshTask?.cancel()
        Task {
            await refreshRuntime()
            await checkForUpdates()
            updateStatusBarIcon?()
        }
        runtimeRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refreshRuntime()
            }
        }
    }

    func endPeriodicRefresh() {
        runtimeRefreshTask?.cancel()
        runtimeRefreshTask = nil
    }

    func startDashboardPolling() {
        stopDashboardPolling()
        Task { await fetchDashboardAll() }

        dashboardEventsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await self?.fetchDashboardEvents()
            }
        }

        dashboardStatusTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.fetchDashboardStatus()
            }
        }
    }

    func stopDashboardPolling() {
        dashboardEventsTask?.cancel()
        dashboardStatusTask?.cancel()
        dashboardEventsTask = nil
        dashboardStatusTask = nil
    }

    func refreshRuntimeForBootstrap() async {
        await refreshRuntime()
    }

    func checkForUpdatesForBootstrap() async {
        await checkForUpdates()
    }

    // MARK: - Commands

    func startDaemon() { executeCommand { try await self.daemonService.start(extraEnv: self.runtime.daemonConfig.envVars) } }
    func stopDaemon() { executeCommand { try await self.daemonService.stop() } }
    func restartDaemon() { executeCommand { try await self.daemonService.restart(extraEnv: self.runtime.daemonConfig.envVars) } }

    func startChannel(_ channelType: String) {
        executeCommand {
            try await self.channelService.startChannel(channelType, extraEnv: self.extraEnv(for: channelType))
        }
    }

    func stopChannel(_ channelType: String) {
        executeCommand { try await self.channelService.stopChannel(channelType) }
    }

    func restartChannel(_ channelType: String) {
        executeCommand {
            let stopOutput = try await self.channelService.stopChannel(channelType)
            let startOutput = try await self.channelService.startChannel(channelType, extraEnv: self.extraEnv(for: channelType))
            return stopOutput + "\n" + startOutput
        }
    }

    func upgradeChannel(_ channelType: String) {
        executeCommand { try await self.channelService.upgradeChannel(channelType) }
    }

    func installChannel(packageName: String) {
        executeCommand { try await self.channelService.installChannel(packageName) }
    }

    func upgradeAll() {
        executeCommand {
            let daemonWasRunning = self.runtime.status.isRunning
            return try await self.upgradeService.upgradeAll(
                daemonInstalledVersion: self.runtime.status.version,
                daemonWasRunning: daemonWasRunning,
                channels: self.runtime.channels,
                latestVersions: self.updates.latestVersions,
                extraEnv: { type in self.extraEnv(for: type) },
                stopChannel: { type in try await self.channelService.stopChannel(type) },
                syncChannel: { pkg in try await self.channelService.syncChannel(pkg) },
                startChannel: { type, env in try await self.channelService.startChannel(type, extraEnv: env) },
                restartDaemon: { try await self.daemonService.restart(extraEnv: self.runtime.daemonConfig.envVars) }
            )
        }
    }

    func showConfigRequired() {
        command.errorMessage = L10n.Channel.feishuConfigRequired
    }

    func checkForUpdatesWithFeedback() {
        guard !command.isLoading else { return }
        command.isLoading = true
        command.errorMessage = nil
        command.lastOutput = ""

        Task { [weak self] in
            guard let self else { return }
            await self.checkForUpdates()
            self.command.isLoading = false
            if !self.hasDuoduoUpdate {
                self.command.lastOutput = L10n.Upgrade.allUpToDate
            }
            self.updateStatusBarIcon?()
        }
    }

    func clearOutput() {
        command.lastOutput = ""
        command.errorMessage = nil
    }

    func openReleasesPage() {
        AppUpdateService.openReleasesPage()
    }

    // MARK: - Dashboard

    func fetchConfig() async {
        dashboard.config = try? await rpc.systemConfig()
    }

    // MARK: - Private

    private func extraEnv(for channelType: String) -> [String: String] {
        ChannelRegistry.entry(for: channelType, feishuConfig: runtime.feishuConfig)?.extraEnv() ?? [:]
    }

    private func executeCommand(_ operation: @escaping () async throws -> String) {
        guard !command.isLoading else { return }
        command.isLoading = true
        command.errorMessage = nil
        command.lastOutput = ""

        Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await operation()
                self.command.lastOutput = output
                await self.refreshRuntime()
            } catch {
                self.command.errorMessage = error.localizedDescription
            }
            self.command.isLoading = false
            self.updateStatusBarIcon?()
        }
    }

    private func refreshRuntime() async {
        reconfigureConnectionsIfNeeded()

        do {
            let newStatus = try await daemonService.getStatus()
            var updated = newStatus
            updated.version = try await daemonService.getVersion()
            if runtime.status != updated { runtime.status = updated }
        } catch {
            runtime.status = DaemonStatus.empty
            runtime.status.output = L10n.Error.prefix(error.localizedDescription)
        }

        var channelInfos: [ChannelInfo] = []
        for entry in ChannelRegistry.channels(feishuConfig: runtime.feishuConfig) {
            if let info = try? await channelService.getChannelStatus(entry.id) {
                channelInfos.append(info)
            }
        }
        if runtime.channels != channelInfos { runtime.channels = channelInfos }
        updateStatusBarIcon?()
    }

    private func checkForUpdates() async {
        if let result = await appUpdateService.fetchLatestRelease() {
            updates.appLatestVersion = result.version
            updates.appLatestReleaseURL = result.url
        }

        if let latest = try? await versionService.getNpmLatestVersion("@openduo/duoduo") {
            updates.latestVersions["daemon"] = latest
        }

        for channel in runtime.channels {
            let pkg = ChannelRegistry.entry(for: channel.type, feishuConfig: runtime.feishuConfig)?.packageName
                ?? "@openduo/channel-\(channel.type)"
            if let latest = try? await versionService.getNpmLatestVersion(pkg) {
                updates.latestVersions[channel.type] = latest
            }
        }
        updateStatusBarIcon?()
    }

    private func fetchDashboardAll() async {
        async let _: Void = fetchDashboardStatus()
        async let _: Void = fetchDashboardEvents()
    }

    private func fetchDashboardEvents() async {
        reconfigureConnectionsIfNeeded()
        guard let response = try? await rpc.spineTail(afterId: lastEventId, limit: 200) else { return }
        guard !response.events.isEmpty else { return }

        dashboard.events.append(contentsOf: response.events)
        for evt in response.events {
            if let key = evt.session_key, let ts = evt.ts {
                lastSeenBySession[key] = parseDate(ts)
            }
            lastEventId = evt.id
        }
        if dashboard.events.count > maxEvents {
            dashboard.events = Array(dashboard.events.dropFirst(dashboard.events.count - maxEvents))
        }
    }

    private func fetchDashboardStatus() async {
        reconfigureConnectionsIfNeeded()
        async let statusReq = rpc.systemStatus()
        async let usageReq = rpc.usageTotals()
        async let jobsReq = rpc.jobList()

        guard let status = try? await statusReq else { return }
        dashboard.sessions = status.sessions
        dashboard.health = status.health
        dashboard.subconscious = status.subconscious
        dashboard.cadence = status.cadence

        if let usage = try? await usageReq {
            let totals = usage.totals
            dashboard.totalCost = totals.total_cost_usd ?? 0
            dashboard.totalTokens = (totals.total_input_tokens ?? 0) + (totals.total_output_tokens ?? 0) + (totals.total_cache_read_tokens ?? 0)
            dashboard.totalTools = totals.total_tool_calls ?? 0
            let cacheRead = totals.total_cache_read_tokens ?? 0
            let totalIn = (totals.total_input_tokens ?? 0) + cacheRead
            dashboard.cacheHitRate = totalIn > 0 ? Int(round(Double(cacheRead) / Double(totalIn) * 100)) : 0
        }

        if let jobsResp = try? await jobsReq {
            dashboard.jobs = jobsResp.jobs
        }
    }

    private func parseDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s) ?? Date()
    }
}
