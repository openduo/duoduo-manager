import SwiftUI

struct DaemonConfigView: View {
    @Binding var config: DaemonConfig
    var mode: ConfigEditorMode = .panel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var didSave = false

    var body: some View {
        VStack(spacing: 0) {
            if mode == .panel {
                titleBar
                Divider().overlay(ConfigPalette.divider(for: mode))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    workDirSection
                    networkSection
                    runtimeSection
                }
                .padding(.bottom, 16)
            }
            if mode == .inline {
                Divider().overlay(ConfigPalette.divider(for: mode))
                inlineActions
            }
        }
        .frame(width: mode == .panel ? 420 : nil)
        .fixedSize(horizontal: false, vertical: mode == .panel)
        .environment(\.colorScheme, mode == .inline ? .dark : colorScheme)
    }

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
                .foregroundStyle(ConfigPalette.label(for: mode))

            Spacer()

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var workDirSection: some View {
        configRow(mode: mode, label: L10n.DaemonConfig.workDir, hint: L10n.DaemonConfig.workDirHint) {
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

    private var networkSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.network, mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.daemonHost, hint: "ALADUO_DAEMON_HOST") {
                TextField("127.0.0.1", text: $config.daemonHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.listenPort, hint: "ALADUO_PORT") {
                TextField("20233", text: $config.port)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private var runtimeSection: some View {
        Group {
            configSectionLabel(L10n.DaemonConfig.general, mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.logLevel, hint: "ALADUO_LOG_LEVEL") {
                Picker("", selection: $config.logLevel) {
                    Text("debug").tag("debug")
                    Text("info").tag("info")
                    Text("warn").tag("warn")
                    Text("error").tag("error")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.DaemonConfig.permissionMode, hint: "ALADUO_PERMISSION_MODE") {
                Picker("", selection: $config.permissionMode) {
                    Text("default").tag("default")
                    Text("bypassPermissions").tag("bypassPermissions")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var inlineActions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(L10n.Config.cancel) {
                onCancel?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
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
