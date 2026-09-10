import SwiftUI

struct DaemonConfigView: View {
    @Binding var config: DaemonConfig
    var mode: ConfigEditorMode = .panel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Installed duoduo version, used to gate the remote-access UI to
    /// unix-socket builds (see #15). Nil ⇒ unknown ⇒ hide the new UI.
    var installedDaemonVersion: String? = nil
    /// Generate a new remote-access token (`duoduo daemon token new`).
    /// `force` rotates an existing one. Nil when remote access is gated off.
    var onNewDaemonToken: ((_ force: Bool) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var didSave = false

    /// True when the running CLI is a unix-socket build, so the remote-access
    /// surface (remote port + token) and the non-loopback host warning apply.
    private var supportsUnixSocket: Bool {
        DuoduoCompat.meetsMinimum(
            installed: installedDaemonVersion,
            minimum: DuoduoCompat.minVersionForUnixSocket
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if mode == .panel {
                titleBar
                Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    workDirSection
                    networkSection
                    if supportsUnixSocket {
                        remoteAccessSection
                    }
                    runtimeSection
                }
                .padding(.bottom, 16)
            }
            if mode == .inline {
                Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
                inlineActions
            }
        }
        .frame(width: mode == .panel ? 420 : nil)
        .fixedSize(horizontal: false, vertical: mode == .panel)
        .background(mode == .panel ? OpenDuo.page : Color.clear)
        .odChrome()
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            ODKicker(text: L10n.DaemonConfig.title, tint: OpenDuo.textSecondary)

            Spacer()

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(ODPrimaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var workDirSection: some View {
        configRow(mode: mode, label: L10n.DaemonConfig.workDir, hint: L10n.DaemonConfig.workDirHint) {
            HStack(spacing: 6) {
                configTextField(text: $config.workDir)

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
                .buttonStyle(ODOutlineButtonStyle())
            }
        }
    }

    private var networkSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.network, mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.daemonHost, hint: "ALADUO_DAEMON_HOST") {
                configTextField(text: $config.daemonHost, placeholder: "127.0.0.1")
            }
            if supportsUnixSocket && config.isNonLoopbackHost {
                remoteHostWarningRow
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.listenPort, hint: "ALADUO_PORT") {
                configTextField(text: $config.port, placeholder: "20233")
            }
        }
    }

    /// Warns that a non-loopback host now selects the opt-in remote listener
    /// (fail-close without token + remote port). Shown only on unix-socket
    /// builds so it never appears on the currently-released CLI (see #15).
    private var remoteHostWarningRow: some View {
        HStack(alignment: .top, spacing: 6) {
            ODStateTick(tint: OpenDuo.attention, size: 5)
                .padding(.top, 3)
            Text(L10n.DaemonConfig.remoteHostWarning)
                .font(.system(size: 10))
                .foregroundStyle(OpenDuo.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// Remote (bearer-authenticated) listener configuration. Opt-in: the
    /// listener starts only when host + remote port + token are all present.
    /// Token is generated via the CLI; manager never stores its plaintext
    /// (per upstream guidance in #15).
    private var remoteAccessSection: some View {
        Group {
            configRowDivider(mode: mode)
            configSectionLabel(L10n.DaemonConfig.remoteAccess, mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.remotePort, hint: L10n.DaemonConfig.remotePortHint) {
                configTextField(text: $config.remotePort, placeholder: L10n.DaemonConfig.remotePortPlaceholder)
            }
            if config.hasRemotePortCollision {
                remotePortCollisionRow
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.daemonToken, hint: L10n.DaemonConfig.daemonTokenHint) {
                HStack(spacing: 6) {
                    if let onNewDaemonToken {
                        Button(L10n.DaemonConfig.daemonTokenNew) {
                            onNewDaemonToken(false)
                        }
                        .buttonStyle(ODOutlineButtonStyle())
                        Button(L10n.DaemonConfig.daemonTokenRotate) {
                            onNewDaemonToken(true)
                        }
                        .buttonStyle(ODOutlineButtonStyle())
                    }
                    Spacer()
                }
            }
            configRowDivider(mode: mode)
            Text(L10n.DaemonConfig.remoteRequiresRestart)
                .font(.odMono(9))
                .foregroundStyle(OpenDuo.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
    }

    private var remotePortCollisionRow: some View {
        HStack(alignment: .top, spacing: 6) {
            ODStateTick(tint: OpenDuo.attention, size: 5)
                .padding(.top, 3)
            Text(L10n.DaemonConfig.remotePortCollision(config.port))
                .font(.system(size: 10))
                .foregroundStyle(OpenDuo.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var runtimeSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.general, mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.logLevel, hint: "ALADUO_LOG_LEVEL") {
                ODSegmentedPicker(
                    selection: $config.logLevel,
                    options: [("debug", "debug"), ("info", "info"), ("warn", "warn"), ("error", "error")]
                )
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.permissionMode, hint: "ALADUO_PERMISSION_MODE") {
                ODSegmentedPicker(
                    selection: $config.permissionMode,
                    options: [("default", "default"), ("bypassPermissions", "bypassPermissions")]
                )
            }
        }
    }

    private var inlineActions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(L10n.Config.cancel) {
                onCancel?()
            }
            .buttonStyle(ODOutlineButtonStyle())

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(ODPrimaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var saveButtonTitle: String {
        didSave ? L10n.Config.saved : L10n.Config.save
    }

    private func saveConfig() {
        config.save()
        didSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didSave = false
        }
        if let onSave {
            onSave()
        } else {
            dismiss()
        }
    }
}
