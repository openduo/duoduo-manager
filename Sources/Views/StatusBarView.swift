import SwiftUI

@MainActor
struct StatusBarView: View {
    @Bindable var viewModel: DaemonViewModel
    var openDashboard: (() -> Void)?
    var openReader: (() -> Void)?

    @State var dashboardViewModel: DashboardViewModel?
    @State var expandedEventIDs: Set<String> = []

    let panelWidth: CGFloat = 568
    let panelHeight: CGFloat = 734
    let panelInset: CGFloat = 14
    let overviewSpacing: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderBar(
                runtimeLive: headerPresentation.runtimeLive,
                controlBusy: headerPresentation.controlBusy,
                eventCount: headerPresentation.eventCount,
                showAppUpdate: headerPresentation.showAppUpdate,
                appVersion: headerPresentation.appVersion,
                showRuntimeUpdate: headerPresentation.showRuntimeUpdate,
                isLoading: headerPresentation.isLoading,
                onAppUpdate: { viewModel.openReleasesPage() },
                onRuntimeAction: {
                    if showRuntimeUpdate {
                        viewModel.upgradeAll()
                    } else {
                        viewModel.checkForUpdatesWithFeedback()
                    }
                }
            )

            Divider().overlay(ConsolePalette.divider)

            ScrollView {
                VStack(spacing: 14) {
                    overviewRow
                    subconsciousPanel
                    streamPanel
                    executionPanel
                    transientOutputPanel
                }
                .padding(panelInset)
            }

            Divider().overlay(ConsolePalette.divider)

            StatusFooterBar(
                loadLabel: footerPresentation.loadLabel,
                loadValue: footerPresentation.loadValue,
                eventFlow: footerPresentation.eventFlow,
                onDashboard: { openDashboard?() },
                onReader: { openCCReader() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(ConsolePalette.background)
        .task {
            ensureDashboardViewModel()
            dashboardViewModel?.startPolling()
        }
        .onDisappear {
            dashboardViewModel?.stopPolling()
        }
        .onChange(of: viewModel.daemonConfig.daemonURL) { _, _ in
            dashboardViewModel?.stopPolling()
            dashboardViewModel = nil
            ensureDashboardViewModel()
            dashboardViewModel?.startPolling()
        }
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 14) {
            controlPanel
                .frame(width: overviewControlWidth)

            topologySummaryPanel
                .frame(width: overviewTopologyWidth)
        }
    }

    private var topologySummaryPanel: some View {
        StatusPanelSection(icon: "point.3.connected.trianglepath.dotted", title: "Topology") {
            VStack(spacing: 12) {
                StatusTopologyMetric(
                    icon: "dot.radiowaves.left.and.right",
                    title: "daemon endpoint",
                    value: topologyPresentation.endpoint
                )
                StatusTopologyMetric(
                    icon: "network",
                    title: "runtime host",
                    value: topologyPresentation.runtimeHost
                )
                StatusTopologyMetric(
                    icon: "cpu",
                    title: "process",
                    value: topologyPresentation.process
                )
                StatusTopologyMetric(
                    icon: "cross.case",
                    title: "system",
                    value: topologyPresentation.system,
                    tint: topologyPresentation.systemTint
                )
            }
        }
    }

    private var subconsciousPanel: some View {
        StatusPanelSection(icon: "brain.head.profile", title: "Subconscious") {
            StatusSubconsciousList(rows: topologyPresentation.subconsciousRows)
        }
    }

    private var overviewAvailableWidth: CGFloat {
        panelWidth - (panelInset * 2) - overviewSpacing
    }

    private var overviewControlWidth: CGFloat {
        floor(overviewAvailableWidth * 0.6)
    }

    private var overviewTopologyWidth: CGFloat {
        ceil(overviewAvailableWidth * 0.4)
    }

    private var controlPanel: some View {
        StatusPanelSection(icon: "slider.horizontal.3", title: "Control Plane", hint: controlHint) {
            VStack(spacing: 10) {
                daemonControlCard

                if let entry = ChannelRegistry.channels(feishuConfig: viewModel.feishuConfig).first {
                    if let channel = viewModel.channels.first(where: { $0.type == entry.id }) {
                        channelControlCard(channel)
                    } else {
                        channelInstallCard(entry)
                    }
                }
            }
        }
    }

    private var daemonControlCard: some View {
        StatusServiceCard(
            icon: daemonCardPresentation.icon,
            name: daemonCardPresentation.name,
            version: daemonCardPresentation.version,
            hasUpdate: daemonCardPresentation.hasUpdate,
            latestVersion: daemonCardPresentation.latestVersion,
            pid: daemonCardPresentation.pid,
            isRunning: daemonCardPresentation.isRunning,
            isLoading: daemonCardPresentation.isLoading,
            onConfig: {
                showConfigPanel(title: L10n.DaemonConfig.title) {
                    DaemonConfigView(config: $viewModel.daemonConfig)
                }
            },
            onStop: { viewModel.stopDaemon() },
            onRestart: { viewModel.restartDaemon() },
            onStart: { viewModel.startDaemon() }
        )
    }

    private func channelControlCard(_ channel: ChannelInfo) -> some View {
        let needsConfig = channel.type == "feishu" && !viewModel.feishuConfig.isConfigured
        let presentation = channelCardPresentation(channel)

        return StatusServiceCard(
            icon: presentation.icon,
            name: presentation.name,
            version: presentation.version,
            hasUpdate: presentation.hasUpdate,
            latestVersion: presentation.latestVersion,
            pid: presentation.pid,
            isRunning: presentation.isRunning,
            isLoading: presentation.isLoading,
            onConfig: channel.type == "feishu" ? {
                showConfigPanel(title: L10n.Channel.feishuConfigHint) {
                    FeishuConfigView(config: $viewModel.feishuConfig)
                }
            } : nil,
            onStop: { viewModel.stopChannel(channel.type) },
            onRestart: {
                if needsConfig {
                    viewModel.showConfigRequired()
                } else {
                    viewModel.restartChannel(channel.type)
                }
            },
            onStart: {
                if needsConfig {
                    viewModel.showConfigRequired()
                } else {
                    viewModel.startChannel(channel.type)
                }
            }
        )
    }

    private func channelInstallCard(_ entry: ChannelEntry) -> some View {
        let presentation = channelInstallPresentation(entry)

        return StatusInstallCard(
            iconName: presentation.iconName,
            name: presentation.name,
            packageName: presentation.packageName,
            isLoading: presentation.isLoading,
            onConfig: entry.id == "feishu" ? {
                showConfigPanel(title: L10n.Channel.feishuConfigHint) {
                    FeishuConfigView(config: $viewModel.feishuConfig)
                }
            } : nil,
            onInstall: {
                viewModel.installChannel(packageName: entry.packageName)
            }
        )
    }

    private var streamPanel: some View {
        StatusRuntimeStreamPanel(
            hint: streamPresentation.hint,
            lastOutput: streamPresentation.lastOutput,
            errorMessage: streamPresentation.errorMessage,
            recentEvents: streamPresentation.recentEvents,
            expandedEventIDs: streamPresentation.expandedEventIDs,
            onToggle: toggleEvent
        )
    }

    private var executionPanel: some View {
        StatusExecutionPanel(
            hint: executionPresentation.hint,
            sessionCaption: executionPresentation.sessionCaption,
            jobCaption: executionPresentation.jobCaption,
            sessionRows: executionPresentation.sessionRows,
            jobRows: executionPresentation.jobRows
        )
    }

    private var transientOutputPanel: some View {
        Group {
            if !viewModel.lastOutput.isEmpty || viewModel.errorMessage != nil {
                HStack(spacing: 8) {
                    Spacer()

                    Button(L10n.Status.clear) {
                        viewModel.clearOutput()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
                }
            }
        }
    }
}
