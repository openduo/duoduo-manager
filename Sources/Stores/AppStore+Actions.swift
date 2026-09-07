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
                do {
                    let skillsOutput = try await skillService.refreshSkills()
                    if !skillsOutput.isEmpty {
                        command.lastOutput += skillsOutput
                    }
                } catch {
                    command.lastOutput += "\n[skills] refresh failed (non-fatal): \(error.localizedDescription)\n"
                }
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

    /// Manual restart from the menubar card. A deliberate human action —
    /// Manager knows this where the CLI cannot, so attribute it explicitly
    /// (see #13). `--reason` is dropped automatically on CLIs too old to
    /// accept it (see `DaemonService.restart(reason:installedVersion:)`).
    func restartDaemon() {
        executeCommand {
            try await self.daemonService.restart(
                extraEnv: [:],
                reason: "manual restart from duoduo-manager menubar",
                installedVersion: self.runtime.status.version
            )
        }
    }

    /// Generate a new remote-access bearer token via `duoduo daemon token
    /// new`. The token body lands in `command.lastOutput` (it is printed
    /// once to stdout); manager never persists it. Pass `force` to rotate.
    /// Available only on unix-socket builds (0.7.0+) — gate the caller on
    /// `DuoduoCompat.meetsMinimum(... minVersionForUnixSocket)` (see #15).
    func newDaemonToken(force: Bool = false) {
        executeCommand {
            try await self.daemonService.newDaemonToken(force: force)
        }
    }

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

    /// Manual install / refresh of the bundled `openduo/duoduo` skills into
    /// `~/.claude/skills`. Same command the upgrade flow runs after a daemon
    /// update; exposed here so an operator can recover without waiting for
    /// the next CLI bump.
    func installSkills() {
        executeCommand(
            activeOperation: .installSkills,
            initialOutput: L10n.Skills.installing
        ) {
            do {
                _ = try await self.skillService.refreshSkills()
                return L10n.Skills.installSuccess
            } catch {
                throw SkillInstallError()
            }
        }
    }

    func upgradeAll() {
        executeCommand(
            activeOperation: .upgradeAll,
            initialOutput: upgradeAllProgressMessage()
        ) {
            let output = try await self.upgradeService.upgradeAll(
                daemonInstalledVersion: self.runtime.status.version,
                channels: self.runtime.channels,
                latestVersions: self.updates.latestVersions,
                stopChannel: { type in try await self.channelService.stopChannel(type) },
                syncChannel: { pkg in try await self.channelService.syncChannel(pkg) },
                startChannel: { type in try await self.channelService.startChannel(type, extraEnv: [:]) },
                refreshSkills: { try await self.skillService.refreshSkills() }
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
            // Skills describe the CLI surface, so they refresh alongside it
            // (see #11). Counted as part of the same component move.
            lines.append("skills: → v\(latest) (with CLI)")
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

private struct SkillInstallError: LocalizedError {
    var errorDescription: String? { L10n.Skills.installFailed }
}
