import SwiftUI

@MainActor
struct StatusBarView: View {
    @Bindable var store: AppStore
    var openDashboard: (() -> Void)?
    var openReader: (() -> Void)?

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

    init(store: AppStore, openDashboard: (() -> Void)? = nil, openReader: (() -> Void)? = nil) {
        self.store = store
        self.openDashboard = openDashboard
        self.openReader = openReader
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
                onAppUpdate: { store.openReleasesPage() },
                onRuntimeAction: {
                    if statusBarPresentation.header.showRuntimeUpdate {
                        store.upgradeAll()
                    } else {
                        store.checkForUpdatesWithFeedback()
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
                loadLabel: statusBarPresentation.footer.loadLabel,
                loadValue: statusBarPresentation.footer.loadValue,
                eventFlow: statusBarPresentation.footer.eventFlow,
                onDashboard: { openDashboard?() },
                onReader: { openCCReader() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(ConsolePalette.background)
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: overviewSpacing) {
            controlPanel
                .frame(width: overviewControlWidth)

            topologySummaryPanel
                .frame(width: overviewTopologyWidth)
        }
    }

    private var topologySummaryPanel: some View {
        StatusPanelSection(icon: "point.3.connected.trianglepath.dotted", title: "Topology") {
            VStack(spacing: 12) {
                StatusTopologyMetric(icon: "dot.radiowaves.left.and.right", title: "daemon endpoint", value: statusBarPresentation.topology.endpoint)
                StatusTopologyMetric(icon: "network", title: "runtime host", value: statusBarPresentation.topology.runtimeHost)
                StatusTopologyMetric(icon: "cpu", title: "process", value: statusBarPresentation.topology.process)
                StatusTopologyMetric(icon: "cross.case", title: "system", value: statusBarPresentation.topology.system, tint: statusBarPresentation.topology.systemTint)
            }
        }
    }

    private var subconsciousPanel: some View {
        StatusPanelSection(icon: "brain.head.profile", title: "Subconscious") {
            StatusSubconsciousList(rows: statusBarPresentation.topology.subconsciousRows)
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
        StatusPanelSection(icon: "slider.horizontal.3", title: "Control Plane", hint: statusBarPresentation.controlHint) {
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
            lastOutput: statusBarPresentation.stream.lastOutput,
            errorMessage: statusBarPresentation.stream.errorMessage,
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
        Group {
            if !store.command.lastOutput.isEmpty || store.command.errorMessage != nil {
                HStack(spacing: 8) {
                    Spacer()

                    Button(L10n.Status.clear) {
                        store.clearOutput()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
                }
            }
        }
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
