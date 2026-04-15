import SwiftUI

@MainActor
struct StatusBarPresentationMapper {
    let store: AppStore

    func make(expandedEventIDs: Set<String>) -> StatusBarPresentationBundle {
        let recentEvents = Array(store.dashboard.events.suffix(6).reversed())
        let activeSessionCount = store.dashboard.sessions.filter { $0.status == "active" }.count
        let runningJobCount = store.dashboard.jobs.filter { store.isJobRunning($0.id) }.count
        let showRuntimeUpdate = store.hasDuoduoUpdate

        return StatusBarPresentationBundle(
            header: StatusHeaderPresentation(
                runtimeLive: store.runtime.status.isRunning,
                controlBusy: store.command.isLoading,
                eventCount: store.dashboard.events.count,
                showAppUpdate: store.hasAppUpdate,
                appVersion: store.updates.appLatestVersion ?? "1.5.0",
                showRuntimeUpdate: showRuntimeUpdate,
                isLoading: store.command.isLoading
            ),
            topology: StatusTopologyPresentation(
                endpoint: store.runtime.daemonConfig.daemonURL,
                runtimeHost: nodeAddressValue,
                process: store.runtime.status.pid.isEmpty ? "pid pending" : "pid \(store.runtime.status.pid)",
                system: systemHealthSummary,
                systemTint: systemHealthTint,
                subconsciousRows: subconsciousRows
            ),
            daemonCard: StatusServiceCardPresentation(
                icon: "server.rack",
                name: "daemon",
                version: store.runtime.status.version,
                hasUpdate: store.hasUpdate(type: "daemon", installedVersion: store.runtime.status.version),
                latestVersion: store.updates.latestVersions["daemon"] ?? "0.4.7",
                pid: store.runtime.status.pid,
                isRunning: store.runtime.status.isRunning,
                isLoading: store.command.isLoading
            ),
            stream: StatusRuntimeStreamPresentation(
                hint: streamHint(recentEvents: recentEvents),
                lastOutput: store.command.lastOutput,
                errorMessage: store.command.errorMessage,
                recentEvents: recentEvents,
                expandedEventIDs: expandedEventIDs
            ),
            execution: StatusExecutionPresentation(
                hint: "active entities",
                sessionCaption: "\(activeSessionCount) active",
                jobCaption: "\(runningJobCount) running",
                sessionRows: sessionSummaryRows,
                jobRows: jobSummaryRows
            ),
            footer: StatusFooterPresentation(
                loadLabel: "ACTIVE LOAD",
                loadValue: "\(activeSessionCount)s / \(runningJobCount)j",
                eventFlow: recentEvents.count
            ),
            controlHint: showRuntimeUpdate ? "updates ready" : (store.command.isLoading ? "commands in flight" : "direct operations")
        )
    }

    func channelCard(for channel: ChannelInfo) -> StatusServiceCardPresentation {
        StatusServiceCardPresentation(
            icon: channelControlIcon(for: channel.type),
            name: channel.displayName,
            version: channel.version,
            hasUpdate: store.hasUpdate(type: channel.type, installedVersion: channel.version),
            latestVersion: store.updates.latestVersions[channel.type] ?? "0.3.1",
            pid: channel.pid,
            isRunning: channel.isRunning,
            isLoading: store.command.isLoading
        )
    }

    func installCard(for entry: ChannelEntry) -> StatusInstallCardPresentation {
        StatusInstallCardPresentation(
            iconName: channelControlIcon(for: entry.id),
            name: entry.displayName,
            packageName: entry.packageName,
            isLoading: store.command.isLoading
        )
    }

    private var nodeAddressValue: String {
        let host = store.runtime.daemonConfig.host
        if host == "127.0.0.1" || host == "localhost" {
            return "local runtime"
        }
        return host
    }

    private var systemHealthSummary: String {
        let gateway = store.dashboard.health?.gateway ?? "unknown"
        let meta = store.dashboard.health?.meta_session ?? "unknown"
        return "gw:\(gateway) · meta:\(meta)"
    }

    private var systemHealthTint: Color {
        if store.dashboard.health?.gateway == "down" || store.dashboard.health?.meta_session == "down" {
            return ConsolePalette.critical
        }
        if store.dashboard.health?.gateway == "ok" {
            return ConsolePalette.signal
        }
        return ConsolePalette.warning
    }

    private var subconsciousRows: [SummaryRowData] {
        (store.dashboard.subconscious?.partitions ?? []).map { partition in
            SummaryRowData(
                title: shortPartitionName(partition.name),
                detail: partition.done ? "partition warm and ready" : "partition currently executing",
                state: partition.done ? "WARM" : "RUN",
                tint: partition.done ? ConsolePalette.fuchsia : ConsolePalette.warning
            )
        }
    }

    private var sessionSummaryRows: [SummaryRowData] {
        topSessions.map {
            SummaryRowData(
                title: $0.display_name ?? shortKey($0.session_key),
                detail: sessionDetail($0),
                state: $0.status.uppercased(),
                tint: sessionTint($0)
            )
        }
    }

    private var jobSummaryRows: [SummaryRowData] {
        topJobs.map { job in
            let running = store.isJobRunning(job.id)
            return SummaryRowData(
                title: shortKey(job.id),
                detail: jobDetail(job, running: running),
                state: running ? "RUN" : (job.state?.last_result ?? "idle").uppercased(),
                tint: jobTint(job, running: running)
            )
        }
    }

    private var topSessions: [SessionInfo] {
        let prioritized = store.dashboard.sessions.sorted {
            let lhsActive = $0.status == "active"
            let rhsActive = $1.status == "active"
            if lhsActive != rhsActive { return lhsActive && !rhsActive }
            return ($0.last_event_at ?? "") > ($1.last_event_at ?? "")
        }
        return Array(prioritized.prefix(4))
    }

    private var topJobs: [JobInfo] {
        let prioritized = store.dashboard.jobs.sorted { lhs, rhs in
            let lhsRunning = store.isJobRunning(lhs.id)
            let rhsRunning = store.isJobRunning(rhs.id)
            if lhsRunning != rhsRunning { return lhsRunning && !rhsRunning }
            return (lhs.state?.last_run_at ?? "") > (rhs.state?.last_run_at ?? "")
        }
        return Array(prioritized.prefix(4))
    }

    private func streamHint(recentEvents: [SpineEvent]) -> String {
        if !store.command.lastOutput.isEmpty { return "command feedback" }
        if let error = store.command.errorMessage, !error.isEmpty { return "attention required" }
        return recentEvents.isEmpty ? "waiting for activity" : "live event feed"
    }

    private func sessionTint(_ session: SessionInfo) -> Color {
        switch session.status {
        case "active":
            return ConsolePalette.signal
        case "error":
            return ConsolePalette.critical
        case "ended":
            return ConsolePalette.mutedText
        default:
            return ConsolePalette.accent
        }
    }

    private func sessionDetail(_ session: SessionInfo) -> String {
        var parts: [String] = []
        if let last = session.last_event_at { parts.append(DashboardTheme.timeAgo(last)) }
        if let health = session.health { parts.append(health) }
        return parts.isEmpty ? "idle" : parts.joined(separator: " · ")
    }

    private func jobTint(_ job: JobInfo, running: Bool) -> Color {
        if running { return ConsolePalette.warning }
        switch job.state?.last_result {
        case "failure":
            return ConsolePalette.critical
        case "success":
            return ConsolePalette.accent
        default:
            return ConsolePalette.mutedText
        }
    }

    private func jobDetail(_ job: JobInfo, running: Bool) -> String {
        if running, let last = job.state?.last_run_at {
            return DashboardTheme.timeAgo(last)
        }
        if let cron = job.frontmatter?.cron, !cron.isEmpty {
            return cron
        }
        if let last = job.state?.last_run_at {
            return DashboardTheme.timeAgo(last)
        }
        return "idle"
    }

    private func shortKey(_ key: String) -> String {
        if key.count <= 20 { return key }
        return String(key.prefix(9)) + "…" + String(key.suffix(7))
    }

    private func shortPartitionName(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(10)) + "…"
    }

    private func channelControlIcon(for type: String) -> String {
        switch type {
        case "feishu":
            return "message.badge.waveform.fill"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}
