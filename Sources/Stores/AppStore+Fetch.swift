import Foundation

extension AppStore {
    func extraEnv(for channelType: String) -> [String: String] {
        ChannelRegistry.entry(for: channelType, feishuConfig: runtime.feishuConfig)?.extraEnv() ?? [:]
    }

    func executeCommand(_ operation: @escaping () async throws -> String) {
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
                if !self.visibleSurfaces.isEmpty {
                    await self.fetchDashboardStatus()
                }
            } catch {
                self.command.errorMessage = error.localizedDescription
            }
            self.command.isLoading = false
            self.scheduleCommandFeedbackAutoClear()
            self.updateStatusBarIcon?()
        }
    }

    func refreshRuntime() async {
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

    func checkForUpdates(force: Bool) async {
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

    func fetchDashboardAll() async {
        async let _: Void = fetchDashboardStatus()
        async let _: Void = fetchDashboardEvents()
    }

    func fetchDashboardEvents() async {
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

    func fetchDashboardStatus() async {
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

    func parseDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s) ?? Date()
    }
}
