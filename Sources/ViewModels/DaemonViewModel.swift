import Foundation

@MainActor
@Observable
final class DaemonViewModel {
    private(set) var status = DaemonStatus.empty
    private(set) var channels: [ChannelInfo] = []
    private(set) var isLoading = false
    private(set) var lastOutput = ""
    private(set) var errorMessage: String?

    private var daemonService: DaemonService!
    private var channelService: ChannelService!
    private let versionService = VersionService()
    private let upgradeService = UpgradeService()
    private var refreshTask: Task<Void, Never>?

    init() {
        let config = DaemonConfig.load()
        self.feishuConfig = FeishuConfig.load()
        self.daemonConfig = config
        self.daemonService = DaemonService()
        self.channelService = ChannelService()
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

    /// Update all components: daemon + channels with new versions
    func upgradeAll() {
        executeCommand {
            try await self.upgradeService.upgradeAll(
                channels: self.channels,
                extraEnv: { type in self.extraEnv(for: type) },
                installChannel: { pkg in try await self.channelService.installChannel(pkg) },
                startChannel: { type, env in try await self.channelService.startChannel(type, extraEnv: env) }
            )
        }
    }

    var hasAnyUpdate: Bool {
        status.hasUpdate || channels.contains { $0.hasUpdate }
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

    // MARK: - Status Refresh

    func refreshStatus() async {
        // Get daemon status and local version
        do {
            var newStatus = try await daemonService.getStatus()
            newStatus.version = try await daemonService.getVersion()
            if status != newStatus { status = newStatus }
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
        // Check latest daemon version
        if let latest = await versionService.checkLatestVersion(repo: "duoduo") {
            if status.latestVersion != latest { status.latestVersion = latest }
        }

        // Check latest channel versions
        for i in channels.indices {
            let type = channels[i].type
            if let latest = await versionService.checkLatestVersion(repo: "channel-\(type)") {
                if channels[i].latestVersion != latest {
                    channels[i].latestVersion = latest
                }
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
            if let self, !self.hasAnyUpdate {
                self.lastOutput = L10n.Upgrade.allUpToDate
            }
        }
    }

    func clearOutput() {
        lastOutput = ""
        errorMessage = nil
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
                self.updateStatusBarIcon?()
            } catch {
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }
}
