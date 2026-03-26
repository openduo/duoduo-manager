import Foundation

@MainActor
@Observable
final class DaemonViewModel {
    private(set) var status = DaemonStatus.empty
    private(set) var channels: [ChannelInfo] = []
    private(set) var isLoading = false
    private(set) var lastOutput = ""
    private(set) var errorMessage: String?
    private(set) var isSettingUp = false

    /// Update check results, keyed by "daemon" or channel type
    private(set) var latestVersions: [String: String] = [:]

    /// Latest app version from GitHub releases (nil = not checked yet)
    private(set) var appLatestVersion: String?
    private(set) var appLatestReleaseURL: URL?

    private var daemonService: DaemonService!
    private var channelService: ChannelService!
    private let versionService = VersionService()
    private let upgradeService = UpgradeService()
    private let appUpdateService = AppUpdateService()
    private var refreshTask: Task<Void, Never>?

    init() {
        let config = DaemonConfig.load()
        self.feishuConfig = FeishuConfig.load()
        self.daemonConfig = config
        self.daemonService = DaemonService(daemonURL: config.daemonURL)
        self.channelService = ChannelService(daemonURL: config.daemonURL)
    }

    /// Ensure duoduo is installed; if not, auto-install it. Returns true when ready.
    func ensureDuoduoInstalled() async {
        guard !NodeRuntime.isDuoduoInstalled else { return }
        isSettingUp = true
        lastOutput = L10n.Setup.installingDuoduo
        do {
            let output = try await NodeRuntime.installDuoduo()
            if NodeRuntime.isDuoduoInstalled {
                lastOutput = L10n.Setup.installSuccess
            } else {
                lastOutput = L10n.Setup.installFailed + "\n" + output
                errorMessage = L10n.Setup.installFailed
            }
        } catch {
            print("[DuoduoManager] duoduo install error: \(error)")
            lastOutput = L10n.Error.prefix(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isSettingUp = false
    }

    // MARK: - Update Check Helpers

    func hasUpdate(type: String, installedVersion: String) -> Bool {
        guard !installedVersion.isEmpty,
              let latest = latestVersions[type], !latest.isEmpty
        else { return false }
        return installedVersion.compare(latest, options: .numeric) == .orderedAscending
    }

    /// Whether daemon or any channel has an update (not including the app itself)
    var hasDuoduoUpdate: Bool {
        hasUpdate(type: "daemon", installedVersion: status.version)
            || channels.contains { hasUpdate(type: $0.type, installedVersion: $0.version) }
    }

    var hasAppUpdate: Bool {
        guard let latest = appLatestVersion else { return false }
        return AppUpdateService.currentVersion.compare(latest, options: .numeric) == .orderedAscending
    }

    // MARK: - Daemon Commands

    func startDaemon() {
        executeCommand {
            try await self.daemonService.start(extraEnv: self.daemonConfig.envVars)
        }
    }

    func stopDaemon() {
        executeCommand {
            try await self.daemonService.stop()
        }
    }

    func restartDaemon() {
        executeCommand {
            try await self.daemonService.restart(extraEnv: self.daemonConfig.envVars)
        }
    }

    /// Update all components: daemon + all channels
    func upgradeAll() {
        executeCommand {
            let daemonWasRunning = self.status.isRunning
            let result = try await self.upgradeService.upgradeAll(
                daemonInstalledVersion: self.status.version,
                daemonWasRunning: daemonWasRunning,
                channels: self.channels,
                latestVersions: self.latestVersions,
                extraEnv: { type in self.extraEnv(for: type) },
                stopChannel: { type in try await self.channelService.stopChannel(type) },
                syncChannel: { pkg in try await self.channelService.syncChannel(pkg) },
                startChannel: { type, env in try await self.channelService.startChannel(type, extraEnv: env) },
                restartDaemon: { try await self.daemonService.restart(extraEnv: self.daemonConfig.envVars) }
            )
            return result
        }
    }

    // MARK: - Channel Config

    var feishuConfig: FeishuConfig
    var daemonConfig: DaemonConfig

    /// Get the extraEnv closure bound to a channel type
    private func extraEnv(for channelType: String) -> [String: String] {
        ChannelRegistry.entry(for: channelType, feishuConfig: feishuConfig)?.extraEnv() ?? [:]
    }

    // MARK: - Channel Commands

    func startChannel(_ channelType: String) {
        executeCommand {
            try await self.channelService.startChannel(
                channelType, extraEnv: self.extraEnv(for: channelType)
            )
        }
    }

    func stopChannel(_ channelType: String) {
        executeCommand {
            try await self.channelService.stopChannel(channelType)
        }
    }

    func restartChannel(_ channelType: String) {
        executeCommand {
            let stopOutput = try await self.channelService.stopChannel(channelType)
            let startOutput = try await self.channelService.startChannel(
                channelType, extraEnv: self.extraEnv(for: channelType)
            )
            return stopOutput + "\n" + startOutput
        }
    }

    func upgradeChannel(_ channelType: String) {
        executeCommand {
            try await self.channelService.upgradeChannel(channelType)
        }
    }

    func installChannel(packageName: String) {
        executeCommand {
            try await self.channelService.installChannel(packageName)
        }
    }

    // MARK: - Status Refresh (periodic only)

    func refreshStatus() async {
        // Get daemon status and local version
        do {
            let newStatus = try await daemonService.getStatus()
            var updated = newStatus
            updated.version = try await daemonService.getVersion()
            if status != updated { status = updated }
        } catch {
            print("[DuoduoManager] getStatus error: \(error)")
            status = DaemonStatus.empty
            status.output = L10n.Error.prefix(error.localizedDescription)
        }

        // Get version + PID + running status for each channel (skip uninstalled)
        var channelInfos: [ChannelInfo] = []
        for entry in ChannelRegistry.channels(feishuConfig: feishuConfig) {
            if let info = try? await channelService.getChannelStatus(entry.id) {
                channelInfos.append(info)
            }
        }
        if channels != channelInfos { channels = channelInfos }
    }

    func checkForUpdates() async {
        // Check latest app version via GitHub releases
        if let result = await appUpdateService.fetchLatestRelease() {
            appLatestVersion = result.version
            appLatestReleaseURL = result.url
        }

        // Check latest daemon version via npm
        if let latest = try? await versionService.getNpmLatestVersion("@openduo/duoduo") {
            latestVersions["daemon"] = latest
        }

        // Check latest channel versions via npm
        for channel in channels {
            let pkg = ChannelRegistry.entry(for: channel.type, feishuConfig: feishuConfig)?.packageName
                ?? "@openduo/channel-\(channel.type)"
            if let latest = try? await versionService.getNpmLatestVersion(pkg) {
                latestVersions[channel.type] = latest
            }
        }
    }

    func checkForUpdatesWithFeedback() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        lastOutput = ""

        Task { [weak self] in
            await self?.checkForUpdates()
            self?.isLoading = false
            if let self, !self.hasDuoduoUpdate {
                self.lastOutput = L10n.Upgrade.allUpToDate
            }
        }
    }

    func clearOutput() {
        lastOutput = ""
        errorMessage = nil
    }

    func openReleasesPage() {
        AppUpdateService.openReleasesPage()
    }

    func showConfigRequired() {
        errorMessage = L10n.Channel.feishuConfigRequired
    }

    // MARK: - Refresh (bound to popover lifecycle)

    func beginPeriodicRefresh(interval: TimeInterval = 30) {
        refreshTask?.cancel()
        Task {
            await refreshStatus()
            await checkForUpdates()
            updateStatusBarIcon?()
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refreshStatus()
            }
        }
    }

    func endPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    var updateStatusBarIcon: (() -> Void)?

    // MARK: - Private

    /// Execute a command: show output, then refresh local status. Update checking is handled by periodic timer.
    private func executeCommand(_ operation: @escaping () async throws -> String) {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        lastOutput = ""

        Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await operation()
                self.lastOutput = output
                await self.refreshStatus()
            } catch {
                print("[DuoduoManager] command error: \(error)")
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}
