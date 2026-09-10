import SwiftUI

@MainActor
struct StatusBarView: View {
    @Bindable var store: AppStore
    var openDashboard: (() -> Void)?
    var openReader: (() -> Void)?
    var openOnboard: (() -> Void)?
    @AppStorage("statusBar.preferredTerminalApp") var preferredTerminalAppRaw: String = PreferredTerminalApp.appleTerminal.rawValue

    @State var expandedEventIDs: Set<String> = []
    @State var expandedConfigTarget: InlineConfigTarget?
    @State var daemonDraft: DaemonConfig
    @State var feishuDraft: FeishuConfig
    @State var daemonNotice: InlineConfigNotice?
    @State var feishuNotice: InlineConfigNotice?
    let panelWidth: CGFloat = 520
    let panelHeight: CGFloat = 680
    let panelInset: CGFloat = 12
    let panelContentInset: CGFloat = 10

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
                isLoading: statusBarPresentation.header.isLoading,
                currentVersion: statusBarPresentation.header.currentVersion,
                costValue: statusBarPresentation.footer.costValue,
                tokenValue: statusBarPresentation.footer.tokenValue,
                cacheValue: statusBarPresentation.footer.cacheValue,
                toolsValue: statusBarPresentation.footer.toolsValue,
                onAppUpdate: { store.checkForSparkleUpdate?() },
                onRefresh: { store.refreshVisibleContentWithFeedback() }
            )

            odHRule()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    overviewRow
                    subconsciousPanel
                    streamPanel
                    executionPanel
                }
                .padding(panelInset)
            }

            odHRule()

            if let message = statusBarPresentation.footer.statusMessage, !message.isEmpty {
                statusBarMessageStrip(message)
            }

            StatusFooterBar(
                preferredTerminalApp: PreferredTerminalApp(rawValue: preferredTerminalAppRaw) ?? .appleTerminal,
                onDashboard: { openDashboard?() },
                onOnboard: { openOnboard?() },
                onReader: { openCCReader() },
                onTerminal: { openTerminal() },
                onSelectTerminalApp: { preferredTerminalAppRaw = $0.rawValue },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(OpenDuo.page)
        .odChrome()
    }

    private var overviewRow: some View {
        OverviewSplit(leadingRatio: 0.54) {
            overviewColumn(
                title: L10n.Status.controlPlane,
                trailing: AnyView(controlPlaneTrailing)
            ) {
                controlPanelContent
            }

            odVRule()
                .frame(maxHeight: .infinity)

            overviewColumn(
                title: L10n.Status.topology
            ) {
                topologySummaryContent
            }
        }
        .frame(maxWidth: .infinity)
        .odPanel()
    }

    @ViewBuilder
    private func overviewColumn<Content: View>(
        title: String,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                ODKicker(text: title, tint: OpenDuo.textKicker)
                Spacer(minLength: 8)
                if let trailing {
                    trailing
                        .layoutPriority(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(panelContentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var controlPlaneTrailing: some View {
        HStack(spacing: 8) {
            if statusBarPresentation.header.showRuntimeUpdate {
                controlPlaneUpdateButton
            }
            StatusOperationsMenu(
                title: statusBarPresentation.operations.title,
                installSkillsTitle: statusBarPresentation.operations.installSkillsTitle,
                autostartTitle: statusBarPresentation.operations.autostartTitle,
                autostartEnabled: statusBarPresentation.operations.autostartEnabled,
                isDisabled: statusBarPresentation.operations.isDisabled,
                onInstallSkills: { store.installSkills() },
                onToggleAutostart: {
                    store.setDaemonAutostart(enabled: !statusBarPresentation.operations.autostartEnabled)
                }
            )
        }
    }

    private var controlPlaneUpdateButton: some View {
        let isUpdatingAll = store.command.activeOperation == .upgradeAll
        return Button(action: { store.upgradeAll() }) {
            HStack(spacing: 4) {
                if isUpdatingAll {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OpenDuo.attention)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(isUpdatingAll ? L10n.Status.updatingAll : L10n.Status.updateAll)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(ODOutlineButtonStyle(tint: OpenDuo.attention))
        .fixedSize(horizontal: true, vertical: false)
        .disabled(store.command.isLoading)
    }

    private var topologySummaryContent: some View {
        VStack(spacing: 10) {
            StatusTopologyMetric(title: "daemon endpoint", value: statusBarPresentation.topology.endpoint)
            StatusTopologyMetric(title: "runtime host", value: statusBarPresentation.topology.runtimeHost)
            StatusTopologyMetric(title: "system", value: statusBarPresentation.topology.system, tint: statusBarPresentation.topology.systemTint)
            StatusTopologyMetric(title: "load", value: statusBarPresentation.topology.load, tint: statusBarPresentation.topology.loadTint)
        }
    }

    private var subconsciousPanel: some View {
        StatusPanelSection(title: L10n.Status.subconscious) {
            StatusSubconsciousList(rows: statusBarPresentation.topology.subconsciousRows)
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
            isPrimaryStartAction: false,
            expandedContent: channel.type == "feishu" && expandedConfigTarget == .feishu
                ? AnyView(feishuInlineConfig)
                : nil
        )
    }

    private func channelInstallCard(_ entry: ChannelEntry) -> some View {
        StatusInstallCard(
            presentation: statusBarMapper.installCard(for: entry),
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

    private func statusBarMessageStrip(_ message: String) -> some View {
        HStack(spacing: 6) {
            ODStateTick(tint: statusBarPresentation.footer.statusIsError ? OpenDuo.alert : OpenDuo.ok, size: 5)
            Text(message)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.odMono(10))
        .foregroundStyle(statusBarPresentation.footer.statusIsError ? OpenDuo.alert : OpenDuo.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var daemonInlineConfig: some View {
        DaemonConfigView(
            config: $daemonDraft,
            mode: .inline,
            onSave: saveDaemonDraft,
            onCancel: { cancelConfig(.daemon) },
            installedDaemonVersion: store.runtime.status.version,
            onNewDaemonToken: { force in store.newDaemonToken(force: force) }
        )
    }

    private var feishuInlineConfig: some View {
        FeishuConfigView(
            config: $feishuDraft,
            mode: .inline,
            onSave: saveFeishuDraft,
            onCancel: { cancelConfig(.feishu) }
        )
    }
}

/// Two flexible columns plus a gutter, sharing the proposed width so the
/// overview plate matches the full-width panels below it.
private struct OverviewSplit: Layout {
    var leadingRatio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else {
            return CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }
        let width = proposal.width ?? 0
        let gutter = subviews[1].sizeThatFits(.unspecified).width
        let inner = max(width - gutter, 0)
        let leading = (inner * leadingRatio).rounded(.towardZero)
        let trailing = inner - leading
        let leadingHeight = subviews[0].sizeThatFits(ProposedViewSize(width: leading, height: proposal.height)).height
        let trailingHeight = subviews[2].sizeThatFits(ProposedViewSize(width: trailing, height: proposal.height)).height
        return CGSize(width: width, height: max(leadingHeight, trailingHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let gutter = subviews[1].sizeThatFits(.unspecified).width
        let inner = max(bounds.width - gutter, 0)
        let leading = (inner * leadingRatio).rounded(.towardZero)
        let trailing = inner - leading
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: leading, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + leading, y: bounds.minY),
            proposal: ProposedViewSize(width: gutter, height: bounds.height)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + leading + gutter, y: bounds.minY),
            proposal: ProposedViewSize(width: trailing, height: bounds.height)
        )
    }
}
