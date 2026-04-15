import SwiftUI

extension StatusBarView {
    var headerPresentation: StatusHeaderPresentation {
        StatusHeaderPresentation(
            runtimeLive: viewModel.status.isRunning,
            controlBusy: viewModel.isLoading,
            eventCount: dashboardViewModel?.events.count ?? 0,
            showAppUpdate: showAppUpdate,
            appVersion: viewModel.appLatestVersion ?? "1.5.0",
            showRuntimeUpdate: showRuntimeUpdate,
            isLoading: viewModel.isLoading
        )
    }

    var topologyPresentation: StatusTopologyPresentation {
        StatusTopologyPresentation(
            endpoint: viewModel.daemonConfig.daemonURL,
            runtimeHost: nodeAddressValue,
            process: viewModel.status.pid.isEmpty ? "pid pending" : "pid \(viewModel.status.pid)",
            system: systemHealthSummary,
            systemTint: systemHealthTint,
            subconsciousRows: subconsciousRows
        )
    }

    var daemonCardPresentation: StatusServiceCardPresentation {
        StatusServiceCardPresentation(
            icon: "server.rack",
            name: "daemon",
            version: viewModel.status.version,
            hasUpdate: showDaemonUpdate,
            latestVersion: daemonUpdateVersion,
            pid: viewModel.status.pid,
            isRunning: viewModel.status.isRunning,
            isLoading: viewModel.isLoading
        )
    }

    func channelCardPresentation(_ channel: ChannelInfo) -> StatusServiceCardPresentation {
        StatusServiceCardPresentation(
            icon: channelControlIcon(for: channel.type),
            name: channel.displayName,
            version: channel.version,
            hasUpdate: showChannelUpdate(channel.type, installedVersion: channel.version),
            latestVersion: channelUpdateVersion(channel.type),
            pid: channel.pid,
            isRunning: channel.isRunning,
            isLoading: viewModel.isLoading
        )
    }

    func channelInstallPresentation(_ entry: ChannelEntry) -> StatusInstallCardPresentation {
        StatusInstallCardPresentation(
            iconName: channelControlIcon(for: entry.id),
            name: entry.displayName,
            packageName: entry.packageName,
            isLoading: viewModel.isLoading
        )
    }

    var streamPresentation: StatusRuntimeStreamPresentation {
        StatusRuntimeStreamPresentation(
            hint: streamHint,
            lastOutput: viewModel.lastOutput,
            errorMessage: viewModel.errorMessage,
            recentEvents: recentEvents,
            expandedEventIDs: expandedEventIDs
        )
    }

    var executionPresentation: StatusExecutionPresentation {
        StatusExecutionPresentation(
            hint: executionHint,
            sessionCaption: "\(activeSessionCount) active",
            jobCaption: "\(runningJobCount) running",
            sessionRows: sessionSummaryRows,
            jobRows: jobSummaryRows
        )
    }

    var footerPresentation: StatusFooterPresentation {
        StatusFooterPresentation(
            sessionLoad: activeSessionCount + runningJobCount,
            eventFlow: recentEvents.count
        )
    }
}

extension StatusBarView {
    var controlHint: String {
        if showRuntimeUpdate { return "updates ready" }
        if viewModel.isLoading { return "commands in flight" }
        return "direct operations"
    }

    var showAppUpdate: Bool {
        viewModel.hasAppUpdate
    }

    var showRuntimeUpdate: Bool {
        viewModel.hasDuoduoUpdate
    }

    var showDaemonUpdate: Bool {
        viewModel.hasUpdate(type: "daemon", installedVersion: viewModel.status.version)
    }

    var daemonUpdateVersion: String {
        viewModel.latestVersions["daemon"] ?? "0.4.7"
    }

    func showChannelUpdate(_ type: String, installedVersion: String) -> Bool {
        viewModel.hasUpdate(type: type, installedVersion: installedVersion)
    }

    func channelUpdateVersion(_ type: String) -> String {
        viewModel.latestVersions[type] ?? "0.3.1"
    }

    var streamHint: String {
        if !viewModel.lastOutput.isEmpty { return "command feedback" }
        if let error = viewModel.errorMessage, !error.isEmpty { return "attention required" }
        return recentEvents.isEmpty ? "waiting for activity" : "live event feed"
    }

    var executionHint: String {
        "active entities"
    }
}

extension StatusBarView {
    var activeSessionCount: Int {
        dashboardViewModel?.sessions.filter { $0.status == "active" }.count ?? 0
    }

    var runningJobCount: Int {
        dashboardViewModel?.jobs.filter { dashboardViewModel?.isJobRunning($0.id) == true }.count ?? 0
    }

    var subconsciousWarmCount: Int {
        dashboardViewModel?.subconscious?.partitions.filter(\.done).count ?? 0
    }

    var recentEvents: [SpineEvent] {
        guard let dashboardViewModel else { return [] }
        return Array(dashboardViewModel.events.suffix(6).reversed())
    }

    var subconsciousPartitions: [SubconsciousPartition] {
        dashboardViewModel?.subconscious?.partitions ?? []
    }

    var topSessions: [SessionInfo] {
        guard let sessions = dashboardViewModel?.sessions else { return [] }
        let prioritized = sessions.sorted {
            let lhsActive = $0.status == "active"
            let rhsActive = $1.status == "active"
            if lhsActive != rhsActive { return lhsActive && !rhsActive }
            return ($0.last_event_at ?? "") > ($1.last_event_at ?? "")
        }
        return Array(prioritized.prefix(4))
    }

    var topJobs: [JobInfo] {
        guard let jobs = dashboardViewModel?.jobs else { return [] }
        let prioritized = jobs.sorted { lhs, rhs in
            let lhsRunning = dashboardViewModel?.isJobRunning(lhs.id) == true
            let rhsRunning = dashboardViewModel?.isJobRunning(rhs.id) == true
            if lhsRunning != rhsRunning { return lhsRunning && !rhsRunning }
            return (lhs.state?.last_run_at ?? "") > (rhs.state?.last_run_at ?? "")
        }
        return Array(prioritized.prefix(4))
    }

    var nodeAddressValue: String {
        let host = viewModel.daemonConfig.host
        if host == "127.0.0.1" || host == "localhost" {
            return "local runtime"
        }
        return host
    }

    var systemHealthSummary: String {
        let gateway = dashboardViewModel?.health?.gateway ?? "unknown"
        let meta = dashboardViewModel?.health?.meta_session ?? "unknown"
        return "gw:\(gateway) · meta:\(meta)"
    }

    var systemHealthTint: Color {
        if dashboardViewModel?.health?.gateway == "down" || dashboardViewModel?.health?.meta_session == "down" {
            return ConsolePalette.critical
        }
        if dashboardViewModel?.health?.gateway == "ok" {
            return ConsolePalette.signal
        }
        return ConsolePalette.warning
    }

    var subconsciousRows: [SummaryRowData] {
        subconsciousPartitions.map { partition in
            SummaryRowData(
                title: shortPartitionName(partition.name),
                detail: partition.done ? "partition warm and ready" : "partition currently executing",
                state: partition.done ? "WARM" : "RUN",
                tint: partition.done ? ConsolePalette.fuchsia : ConsolePalette.warning
            )
        }
    }

    var sessionSummaryRows: [SummaryRowData] {
        topSessions.map {
            SummaryRowData(
                title: $0.display_name ?? shortKey($0.session_key),
                detail: sessionDetail($0),
                state: $0.status.uppercased(),
                tint: sessionTint($0)
            )
        }
    }

    var jobSummaryRows: [SummaryRowData] {
        topJobs.map { job in
            let running = dashboardViewModel?.isJobRunning(job.id) == true
            return SummaryRowData(
                title: shortKey(job.id),
                detail: jobDetail(job, running: running),
                state: running ? "RUN" : (job.state?.last_result ?? "idle").uppercased(),
                tint: jobTint(job, running: running)
            )
        }
    }

    func sessionTint(_ session: SessionInfo) -> Color {
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

    func sessionDetail(_ session: SessionInfo) -> String {
        var parts: [String] = []
        if let last = session.last_event_at { parts.append(DashboardTheme.timeAgo(last)) }
        if let health = session.health { parts.append(health) }
        return parts.isEmpty ? "idle" : parts.joined(separator: " · ")
    }

    func jobTint(_ job: JobInfo, running: Bool) -> Color {
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

    func jobDetail(_ job: JobInfo, running: Bool) -> String {
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

    func shortKey(_ key: String) -> String {
        if key.count <= 20 { return key }
        return String(key.prefix(9)) + "…" + String(key.suffix(7))
    }

    func shortPartitionName(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(10)) + "…"
    }

    func channelControlIcon(for type: String) -> String {
        switch type {
        case "feishu":
            return "message.badge.waveform.fill"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}

extension StatusBarView {
    func ensureDashboardViewModel() {
        guard dashboardViewModel == nil else { return }
        dashboardViewModel = DashboardViewModel(daemonURL: viewModel.daemonConfig.daemonURL)
    }

    func toggleEvent(_ eventID: String) {
        if expandedEventIDs.contains(eventID) {
            expandedEventIDs.remove(eventID)
        } else {
            expandedEventIDs.insert(eventID)
        }
    }

    func openCCReader() {
        openReader?()
    }

    func showConfigPanel<V: View>(title: String, @ViewBuilder content: @escaping () -> V) {
        let hostingController = NSHostingController(rootView: content())
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = title
        panel.styleMask = [.titled, .closable]
        panel.isReleasedWhenClosed = false
        hostingController.view.layoutSubtreeIfNeeded()
        let size = hostingController.view.fittingSize
        panel.setContentSize(NSSize(width: max(size.width, 380), height: size.height))
        panel.minSize = NSSize(width: 380, height: 200)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
