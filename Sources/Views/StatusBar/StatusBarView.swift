import SwiftUI

@MainActor
struct StatusBarView: View {
    @Bindable var store: AppStore
    var openDashboard: (() -> Void)?
    var openReader: (() -> Void)?
    var openOnboard: (() -> Void)?

    @State var expandedEventIDs: Set<String> = []
    @State var expandedConfigTarget: InlineConfigTarget?
    @State var daemonDraft: DaemonConfig
    @State var feishuDraft: FeishuConfig
    @State var daemonNotice: InlineConfigNotice?
    @State var feishuNotice: InlineConfigNotice?
    let panelWidth: CGFloat = 568
    let panelHeight: CGFloat = 734
    let panelInset: CGFloat = 14
    let overviewSpacing: CGFloat = 14
    let panelContentInset: CGFloat = 12
    let overviewDividerWidth: CGFloat = 1

    init(store: AppStore, openDashboard: (() -> Void)? = nil, openReader: (() -> Void)? = nil, openOnboard: (() -> Void)? = nil) {
        self.store = store
        self.openDashboard = openDashboard
        self.openReader = openReader
        self.openOnboard = openOnboard
        _daemonDraft = State(initialValue: store.runtime.daemonConfig)
        _feishuDraft = State(initialValue: store.runtime.feishuConfig)
    }

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderBar(
                runtimeLive: statusBarPresentation.header.runtimeLive,
                controlBusy: statusBarPresentation.header.controlBusy,
                eventCount: statusBarPresentation.header.eventCount,
                showAppUpdate: statusBarPresentation.header.showAppUpdate,
                appVersion: statusBarPresentation.header.appVersion,
                showRuntimeUpdate: statusBarPresentation.header.showRuntimeUpdate,
                isLoading: statusBarPresentation.header.isLoading,
                currentVersion: statusBarPresentation.header.currentVersion,
                onAppUpdate: { store.openReleasesPage() },
                onRefresh: { store.refreshVisibleContentWithFeedback() },
                onUpgrade: { store.upgradeAll() }
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
                costValue: statusBarPresentation.footer.costValue,
                tokenValue: statusBarPresentation.footer.tokenValue,
                cacheValue: statusBarPresentation.footer.cacheValue,
                toolsValue: statusBarPresentation.footer.toolsValue,
                statusMessage: statusBarPresentation.footer.statusMessage,
                statusIsError: statusBarPresentation.footer.statusIsError,
                onDashboard: { openDashboard?() },
                onOnboard: { openOnboard?() },
                onReader: { openCCReader() },
                onTerminal: { openTerminal() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(ConsolePalette.background)
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 0) {
            overviewColumn(
                icon: "slider.horizontal.3",
                title: "Control Plane",
                hint: statusBarPresentation.controlHint
            ) {
                controlPanelContent
            }
                .frame(width: overviewControlWidth)

            Rectangle()
                .fill(ConsolePalette.divider)
                .frame(width: 1)
                .padding(.horizontal, overviewSpacing)

            overviewColumn(
                icon: "point.3.connected.trianglepath.dotted",
                title: "Topology"
            ) {
                topologySummaryContent
            }
                .frame(width: overviewTopologyWidth)
        }
        .consolePanel()
    }

    @ViewBuilder
    private func overviewColumn<Content: View>(
        icon: String,
        title: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.primaryText)

                Spacer()

                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ConsolePalette.secondaryText)
                }
            }

            content()
        }
    }

    private var topologySummaryContent: some View {
        VStack(spacing: 12) {
            StatusTopologyMetric(icon: "dot.radiowaves.left.and.right", title: "daemon endpoint", value: statusBarPresentation.topology.endpoint)
            StatusTopologyMetric(icon: "network", title: "runtime host", value: statusBarPresentation.topology.runtimeHost)
            StatusTopologyMetric(icon: "cross.case", title: "system", value: statusBarPresentation.topology.system, tint: statusBarPresentation.topology.systemTint)
            StatusTopologyMetric(icon: "gauge.with.dots.needle.33percent", title: "load", value: statusBarPresentation.topology.load, tint: statusBarPresentation.topology.loadTint)
        }
    }

    private var subconsciousPanel: some View {
        StatusPanelSection(icon: "brain.head.profile", title: "Subconscious") {
            StatusSubconsciousList(rows: statusBarPresentation.topology.subconsciousRows)
        }
    }

    private var overviewAvailableWidth: CGFloat {
        panelWidth
            - (panelInset * 2)
            - (panelContentInset * 2)
            - (overviewSpacing * 2)
            - overviewDividerWidth
    }

    private var overviewControlWidth: CGFloat {
        floor(overviewAvailableWidth * 0.6)
    }

    private var overviewTopologyWidth: CGFloat {
        ceil(overviewAvailableWidth * 0.4)
    }

    private var controlPanelContent: some View {
        VStack(spacing: 10) {
            daemonControlCard

            if let entry = ChannelRegistry.channels(feishuConfig: store.runtime.feishuConfig).first {
                if let channel = store.runtime.channels.first(where: { $0.type == entry.id }) {
                    channelControlCard(channel)
                } else {
                    channelInstallCard(entry)
                }
            }
        }
    }

    private var daemonControlCard: some View {
        StatusServiceCard(
            icon: statusBarPresentation.daemonCard.icon,
            name: statusBarPresentation.daemonCard.name,
            version: statusBarPresentation.daemonCard.version,
            hasUpdate: statusBarPresentation.daemonCard.hasUpdate,
            latestVersion: statusBarPresentation.daemonCard.latestVersion,
            pid: statusBarPresentation.daemonCard.pid,
            isRunning: statusBarPresentation.daemonCard.isRunning,
            isLoading: statusBarPresentation.daemonCard.isLoading,
            runtimeHint: daemonRuntimeHint,
            runtimeHintTint: daemonRuntimeHintTint,
            onConfig: {
                toggleConfig(.daemon)
            },
            onStop: { store.stopDaemon() },
            onRestart: { store.restartDaemon() },
            onStart: { store.startDaemon() },
            expandedContent: expandedConfigTarget == .daemon
                ? AnyView(daemonInlineConfig)
                : nil
        )
    }

    private func channelControlCard(_ channel: ChannelInfo) -> some View {
        let needsConfig = channel.type == "feishu" && !store.runtime.feishuConfig.isConfigured
        let presentation = statusBarMapper.channelCard(for: channel)

        return StatusServiceCard(
            icon: presentation.icon,
            name: presentation.name,
            version: presentation.version,
            hasUpdate: presentation.hasUpdate,
            latestVersion: presentation.latestVersion,
            pid: presentation.pid,
            isRunning: presentation.isRunning,
            isLoading: presentation.isLoading,
            runtimeHint: feishuRuntimeHint(channelIsRunning: presentation.isRunning),
            runtimeHintTint: feishuRuntimeHintTint(channelIsRunning: presentation.isRunning),
            onConfig: channel.type == "feishu" ? {
                toggleConfig(.feishu)
            } : nil,
            onStop: { store.stopChannel(channel.type) },
            onRestart: {
                if needsConfig {
                    store.showConfigRequired()
                } else {
                    store.restartChannel(channel.type)
                }
            },
            onStart: {
                if needsConfig {
                    store.showConfigRequired()
                } else {
                    store.startChannel(channel.type)
                }
            },
            expandedContent: channel.type == "feishu" && expandedConfigTarget == .feishu
                ? AnyView(feishuInlineConfig)
                : nil
        )
    }

    private func channelInstallCard(_ entry: ChannelEntry) -> some View {
        let presentation = statusBarMapper.installCard(for: entry)

        return StatusInstallCard(
            iconName: presentation.iconName,
            name: presentation.name,
            packageName: presentation.packageName,
            isLoading: presentation.isLoading,
            runtimeHint: nil,
            runtimeHintTint: nil,
            onConfig: entry.id == "feishu" ? {
                toggleConfig(.feishu)
            } : nil,
            onInstall: {
                store.installChannel(packageName: entry.packageName)
            },
            expandedContent: entry.id == "feishu" && expandedConfigTarget == .feishu
                ? AnyView(feishuInlineConfig)
                : nil
        )
    }

    private var streamPanel: some View {
        StatusRuntimeStreamPanel(
            hint: statusBarPresentation.stream.hint,
            recentEvents: statusBarPresentation.stream.recentEvents,
            expandedEventIDs: statusBarPresentation.stream.expandedEventIDs,
            onToggle: toggleEvent
        )
    }

    private var executionPanel: some View {
        StatusExecutionPanel(
            hint: statusBarPresentation.execution.hint,
            sessionCaption: statusBarPresentation.execution.sessionCaption,
            jobCaption: statusBarPresentation.execution.jobCaption,
            sessionRows: statusBarPresentation.execution.sessionRows,
            jobRows: statusBarPresentation.execution.jobRows
        )
    }

    private var transientOutputPanel: some View {
        EmptyView()
    }

    private var daemonInlineConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            DaemonConfigView(
                config: $daemonDraft,
                mode: .inline,
                onSave: saveDaemonDraft,
                onCancel: { cancelConfig(.daemon) }
            )

            if let daemonNotice {
                StatusInlineConfigNotice(
                    message: daemonNotice.message,
                    tint: daemonNotice.tint,
                    actionTitle: daemonNotice.actionTitle,
                    action: daemonNotice.action
                )
            }
        }
    }

    private var feishuInlineConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeishuConfigView(
                config: $feishuDraft,
                mode: .inline,
                onSave: saveFeishuDraft,
                onCancel: { cancelConfig(.feishu) }
            )

            if let feishuNotice {
                StatusInlineConfigNotice(
                    message: feishuNotice.message,
                    tint: feishuNotice.tint,
                    actionTitle: feishuNotice.actionTitle,
                    action: feishuNotice.action
                )
            }
        }
    }
}
