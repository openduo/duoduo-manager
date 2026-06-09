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
        guard !runtimeEnvironment.isDuoduoInstalled else { return }
        guard !runtime.isSettingUp else { return }
        guard runtimeEnvironment.hasBundledNode || runtimeEnvironment.hasSystemNode else {
            command.lastOutput = L10n.Setup.systemNodeMissing
            command.errorMessage = L10n.Setup.systemNodeMissingTitle
            return
        }

        runtime.isSettingUp = true
        command.lastOutput = L10n.Setup.installingDuoduo
        do {
            let output = try await runtimeEnvironment.installDuoduo()
            if runtimeEnvironment.isDuoduoInstalled {
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

    func startDaemon() { executeCommand { try await self.daemonService.start(extraEnv: [:]) } }
    func stopDaemon() { executeCommand { try await self.daemonService.stop() } }
    func restartDaemon() { executeCommand { try await self.daemonService.restart(extraEnv: [:]) } }

    func startChannel(_ channelType: String) {
        executeCommand {
            try await self.channelService.startChannel(channelType, extraEnv: [:])
        }
    }

    func stopChannel(_ channelType: String) {
        executeCommand { try await self.channelService.stopChannel(channelType) }
    }

    func restartChannel(_ channelType: String) {
        executeCommand {
            let stopOutput = try await self.channelService.stopChannel(channelType)
            let startOutput = try await self.channelService.startChannel(channelType, extraEnv: [:])
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
        executeCommand(
            activeOperation: .upgradeAll,
            initialOutput: upgradeAllProgressMessage()
        ) {
            let daemonWasRunning = self.runtime.status.isRunning
            let output = try await self.upgradeService.upgradeAll(
                daemonInstalledVersion: self.runtime.status.version,
                daemonWasRunning: daemonWasRunning,
                channels: self.runtime.channels,
                latestVersions: self.updates.latestVersions,
                stopChannel: { type in try await self.channelService.stopChannel(type) },
                syncChannel: { pkg in try await self.channelService.syncChannel(pkg) },
                startChannel: { type in try await self.channelService.startChannel(type, extraEnv: [:]) },
                restartDaemon: { try await self.daemonService.restart(extraEnv: [:]) }
            )
            return output.isEmpty ? L10n.Upgrade.allUpToDate : output
        }
    }

    private func upgradeAllProgressMessage() -> String {
        var lines: [String] = []

        if let latest = updates.latestVersions["daemon"],
           !latest.isEmpty,
           !runtime.status.version.isEmpty,
           runtime.status.version.compare(latest, options: .numeric) == .orderedAscending
        {
            lines.append("duoduo: v\(runtime.status.version) → v\(latest)")
        }

        for channel in runtime.channels {
            guard let latest = updates.latestVersions[channel.type],
                  !latest.isEmpty,
                  !channel.version.isEmpty,
                  channel.version.compare(latest, options: .numeric) == .orderedAscending
            else { continue }
            lines.append("\(channel.displayName): v\(channel.version) → v\(latest)")
        }

        guard !lines.isEmpty else { return L10n.Upgrade.allUpToDate }
        return ([L10n.Upgrade.updatingCount(lines.count)] + lines).joined(separator: "\n")
    }

    func showConfigRequired() {
        command.errorMessage = L10n.Channel.feishuConfigRequired
        scheduleCommandFeedbackAutoClear()
    }

    func clearOutput() {
        clearCommandFeedbackTask?.cancel()
        clearCommandFeedbackTask = nil
        command.activeOperation = nil
        command.lastOutput = ""
        command.errorMessage = nil
    }

    func fetchConfig() async {
        dashboard.config = try? await rpc.systemConfig()
    }

    func aliasSession(_ sessionKey: String, name: String?) {
        executeCommand {
            let output = try await self.sessionService.alias(sessionKey: sessionKey, name: name)
            await self.fetchDashboardStatus()
            return output
        }
    }

    func notifySession(_ target: String, message: String) {
        executeCommand {
            let output = try await self.sessionService.notify(target: target, message: message, source: "duoduo-atc")
            await self.fetchDashboardStatus()
            return output
        }
    }

    func archiveSession(_ sessionKey: String) {
        executeCommand {
            let output = try await self.sessionService.archive(sessionKey: sessionKey)
            await self.fetchDashboardStatus()
            return output
        }
    }
}
