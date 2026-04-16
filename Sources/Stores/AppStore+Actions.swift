import Foundation

extension AppStore {
    func scheduleCommandFeedbackAutoClear() {
        let outputSnapshot = command.lastOutput
        let errorSnapshot = command.errorMessage

        clearCommandFeedbackTask?.cancel()
        clearCommandFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            if self.command.lastOutput == outputSnapshot, self.command.errorMessage == errorSnapshot {
                self.clearOutput()
            }
            self.clearCommandFeedbackTask = nil
        }
    }

    func updateDaemonConfig(_ config: DaemonConfig) {
        runtime.daemonConfig = config
        reconfigureConnectionsIfNeeded()
        Task { await refreshVisibleContentNow() }
    }

    func updateFeishuConfig(_ config: FeishuConfig) {
        runtime.feishuConfig = config
        Task { await refreshVisibleContentNow() }
    }

    func refreshVisibleContentWithFeedback() {
        guard !command.isLoading else { return }
        command.isLoading = true
        command.errorMessage = nil
        command.lastOutput = ""

        Task { [weak self] in
            guard let self else { return }
            await self.refreshVisibleContentNow()
            self.command.isLoading = false
            self.scheduleCommandFeedbackAutoClear()
            self.updateStatusBarIcon?()
        }
    }

    func ensureDuoduoInstalledIfNeeded() async {
        guard !NodeRuntime.isDuoduoInstalled else { return }
        guard !runtime.isSettingUp else { return }
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
        scheduleCommandFeedbackAutoClear()
        updateStatusBarIcon?()
    }

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
        scheduleCommandFeedbackAutoClear()
    }

    func clearOutput() {
        clearCommandFeedbackTask?.cancel()
        clearCommandFeedbackTask = nil
        command.lastOutput = ""
        command.errorMessage = nil
    }

    func openReleasesPage() {
        AppUpdateService.openReleasesPage()
    }

    func fetchConfig() async {
        dashboard.config = try? await rpc.systemConfig()
    }
}
