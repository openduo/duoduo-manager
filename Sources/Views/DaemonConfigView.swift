import SwiftUI

struct DaemonConfigView: View {
    @Binding var config: DaemonConfig
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    workDirSection
                    networkSection
                    logSection
                    permissionSection
                    sessionSection
                    advancedToggle
                    if showAdvanced { advancedSection }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 380)
        .fixedSize()
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(L10n.DaemonConfig.title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button(L10n.Config.save) {
                config.save()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Working Directory

    private var workDirSection: some View {
        Group {
            configRow(label: L10n.DaemonConfig.workDir, hint: L10n.DaemonConfig.workDirHint) {
                HStack(spacing: 6) {
                    TextField("", text: $config.workDir)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button(L10n.DaemonConfig.workDirSelect) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.message = L10n.DaemonConfig.workDirPanelMessage
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                config.workDir = url.path
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.network)
            configRow(label: L10n.DaemonConfig.listenPort, hint: "ALADUO_PORT") {
                TextField("20233", text: $config.port)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    // MARK: - Logging

    private var logSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.logging)
            configRow(label: L10n.DaemonConfig.logLevel, hint: "ALADUO_LOG_LEVEL") {
                Picker("", selection: $config.logLevel) {
                    Text("debug").tag("debug")
                    Text("info").tag("info")
                    Text("warn").tag("warn")
                    Text("error").tag("error")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - Permissions

    private var permissionSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.permissions)
            configRow(label: L10n.DaemonConfig.permissionMode, hint: "ALADUO_PERMISSION_MODE") {
                Picker("", selection: $config.permissionMode) {
                    Text("default").tag("default")
                    Text("bypassPermissions").tag("bypassPermissions")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.session)
            configRow(label: L10n.DaemonConfig.maxConcurrent, hint: "ALADUO_SESSION_MAX_CONCURRENT") {
                TextField("10", text: $config.maxConcurrent)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    // MARK: - Advanced

    private var advancedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { showAdvanced.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(L10n.DaemonConfig.advancedSettings)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var advancedSection: some View {
        Group {
            configRow(label: L10n.DaemonConfig.idleTimeout, hint: "ALADUO_SESSION_IDLE_MS") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("3600000", text: $config.sessionIdleMs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Text(L10n.DaemonConfig.idleTimeoutHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            configRowDivider()
            configRow(label: L10n.DaemonConfig.disableAutoMain, hint: "ALADUO_DISABLE_DAEMON_AUTO_MAIN") {
                HStack {
                    Toggle("", isOn: $config.disableAutoMain).labelsHidden()
                    Text(config.disableAutoMain ? L10n.DaemonConfig.autoMainDisabled : L10n.DaemonConfig.autoMainDefault)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            configRowDivider()
            configRow(label: L10n.DaemonConfig.pullLimit, hint: "ALADUO_PULL_LIMIT") {
                TextField("50", text: $config.pullLimit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

}
