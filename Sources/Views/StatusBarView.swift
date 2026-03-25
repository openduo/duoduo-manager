import SwiftUI
import CCReaderKit

// MARK: - Root

@MainActor
struct StatusBarView: View {
    @Bindable var viewModel: DaemonViewModel
    var openDashboard: (() -> Void)?
    var openReader: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            Divider()
            VStack(spacing: 12) {
                daemonCard
                channelsSection
            }
            .padding(12)
            Divider()
            appFooter
        }
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 10) {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                let nsImage = NSImage(contentsOf: url)
            {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("Duoduo Manager")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
            }
            // Update button: check for updates if none found, upgrade if updates detected
            Button {
                if viewModel.hasAnyUpdate {
                    viewModel.upgradeAll()
                } else {
                    viewModel.checkForUpdatesWithFeedback()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(
                        systemName: viewModel.hasAnyUpdate
                            ? "arrow.up.circle.fill" : "arrow.up.circle"
                    )
                    .font(.system(size: 12))
                    if viewModel.hasAnyUpdate {
                        Text(L10n.Status.hasUpdate)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(
                    viewModel.hasAnyUpdate ? .orange : Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Daemon Card

    private var daemonCard: some View {
        serviceCard(
            icon: "terminal.fill",
            iconBackground: Color.accentColor.opacity(0.7),
            name: "Daemon",
            version: viewModel.status.version,
            hasUpdate: viewModel.hasUpdate(type: "daemon", installedVersion: viewModel.status.version),
            latestVersion: viewModel.latestVersions["daemon"] ?? "",
            pid: viewModel.status.pid,
            isRunning: viewModel.status.isRunning,
            configButton: {
                Button {
                    showConfigPanel(title: L10n.DaemonConfig.title) {
                        DaemonConfigView(config: $viewModel.daemonConfig)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .help(L10n.DaemonConfig.title)
            },
            onStop: { viewModel.stopDaemon() },
            onRestart: { viewModel.restartDaemon() },
            onStart: { viewModel.startDaemon() }
        )
    }

    // MARK: - Channels Section

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Channels")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(ChannelRegistry.channels(feishuConfig: viewModel.feishuConfig)) { entry in
                let installed = viewModel.channels.first { $0.type == entry.id }
                if let channel = installed {
                    channelInstalledCard(channel)
                } else {
                    channelInstallCard(entry)
                }
            }
        }
    }

    // Installed channel card
    private func channelInstalledCard(_ channel: ChannelInfo) -> some View {
        let needsConfig = channel.type == "feishu" && !viewModel.feishuConfig.isConfigured

        return serviceCard(
            icon: channel.icon,
            iconBackground: Color.accentColor,
            name: channel.displayName,
            version: channel.version,
            hasUpdate: viewModel.hasUpdate(type: channel.type, installedVersion: channel.version),
            latestVersion: viewModel.latestVersions[channel.type] ?? "",
            pid: channel.pid,
            isRunning: channel.isRunning,
            configButton: {
                if channel.type == "feishu" {
                    Button {
                        showConfigPanel(title: L10n.Channel.feishuConfigHint) {
                            FeishuConfigView(config: $viewModel.feishuConfig)
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.Channel.feishuConfigHint)
                }
            },
            onStop: { viewModel.stopChannel(channel.type) },
            onRestart: needsConfig ? { viewModel.showConfigRequired() } : { viewModel.restartChannel(channel.type) },
            onStart: needsConfig ? { viewModel.showConfigRequired() } : { viewModel.startChannel(channel.type) }
        )
    }

    // Uninstalled channel card
    private func channelInstallCard(_ entry: ChannelEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 32, height: 32)
                .background(Color(nsColor: .separatorColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(entry.packageName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Feishu: configure before install
            if entry.id == "feishu" {
                Button {
                    showConfigPanel(title: L10n.Channel.feishuConfigHint) {
                        FeishuConfigView(config: $viewModel.feishuConfig)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text(L10n.Status.configure)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .separatorColor).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.installChannel(packageName: entry.packageName)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text(L10n.Status.install)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(12)
        .card()
    }

    // MARK: - App Footer

    private var appFooter: some View {
        VStack(spacing: 0) {
            // Message row
            if viewModel.errorMessage != nil || !viewModel.lastOutput.isEmpty {
                HStack(spacing: 6) {
                    if let error = viewModel.errorMessage {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10)).foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
                        Spacer()
                        Button(L10n.Status.clear) { viewModel.clearOutput() }
                            .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.tertiary)
                    } else if !viewModel.lastOutput.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundStyle(.green)
                        Text(viewModel.lastOutput)
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button(L10n.Status.clear) { viewModel.clearOutput() }
                            .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                Divider()
            }
            // Actions row
            HStack(spacing: 8) {
                Button {
                    openDashboard?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10))
                        Text("ATC")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .separatorColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                Button {
                    openCCReader()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))
                        Text("Reader")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .separatorColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                Spacer()
                Button(L10n.Status.quit) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }

    // MARK: - Shared

    /// Unified service card used by both Daemon and Channel
    private func serviceCard(
        icon: String,
        iconBackground: Color,
        name: String,
        version: String,
        hasUpdate: Bool,
        latestVersion: String = "",
        pid: String,
        isRunning: Bool,
        @ViewBuilder configButton: @escaping () -> some View = { EmptyView() },
        onStop: @escaping () -> Void,
        onRestart: @escaping () -> Void,
        onStart: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            // Title row: icon + name + config + controls
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(name)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                configButton()

                if isRunning {
                    iconCtrlBtn("stop.fill", .red, action: onStop)
                    iconCtrlBtn("arrow.clockwise", .orange, action: onRestart)
                } else {
                    iconCtrlBtn("play.fill", .green, action: onStart)
                }
            }

            // Metadata row: version · PID · status
            HStack(spacing: 0) {
                if !version.isEmpty {
                    Text("v\(version)")
                        .foregroundStyle(hasUpdate ? .orange : .secondary)
                    if hasUpdate && !latestVersion.isEmpty {
                        Text(" → v\(latestVersion)")
                            .foregroundStyle(.orange)
                    }
                    if !pid.isEmpty {
                        Text(" · ").foregroundStyle(.quaternary)
                    }
                }
                if !pid.isEmpty {
                    Text("PID \(pid)")
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                statusDot(isRunning)
                Text(isRunning ? L10n.Status.running : L10n.Status.stopped)
                    .padding(.leading, 6)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isRunning ? Color.green : Color(nsColor: .secondaryLabelColor))
            }
            .font(.system(size: 10, design: .monospaced))
        }
        .padding(12)
        .card()
    }

    // MARK: - Open CC Reader

    private func openCCReader() {
        openReader?()
    }

    // MARK: - Config Panel Helper

    private func showConfigPanel<V: View>(title: String, @ViewBuilder content: @escaping () -> V) {
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

    private func statusDot(_ running: Bool) -> some View {
        Circle()
            .fill(running ? Color.green : Color(nsColor: .tertiaryLabelColor))
            .frame(width: 6, height: 6)
    }

    private func iconCtrlBtn(
        _ icon: String, _ color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Card Modifier

extension View {
    fileprivate func card() -> some View {
        self
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
    }
}
