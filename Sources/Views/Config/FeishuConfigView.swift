import SwiftUI

struct FeishuConfigView: View {
    @Binding var config: FeishuConfig
    var mode: ConfigEditorMode = .panel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var revealSecret = false
    @State private var didSave = false

    private var isValid: Bool {
        !config.appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !config.appSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if mode == .panel {
                titleBar
                Divider().overlay(ConfigPalette.divider(for: mode))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    authSection
                    connectionSection
                    accessSection
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
            Image(systemName: "message.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(L10n.FeishuConfig.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ConfigPalette.label(for: mode))

            Spacer()

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isValid)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var authSection: some View {
        Group {
            HStack {
                configSectionLabel(L10n.FeishuConfig.auth, mode: mode)
                Spacer()
                Button {
                    if let url = URL(string: "https://open.feishu.cn/page/openclaw?form=multiAgent") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                        Text(L10n.Onboard.createBot)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(ConfigPalette.secondary(for: mode))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 14)
            }
            configRow(mode: mode, label: L10n.FeishuConfig.appID, required: true, hint: "FEISHU_APP_ID") {
                TextField("cli_xxxxxxxxxx", text: $config.appId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.appSecret, required: true, hint: "FEISHU_APP_SECRET") {
                HStack(spacing: 6) {
                    Group {
                        if revealSecret {
                            TextField("", text: $config.appSecret)
                        } else {
                            SecureField("", text: $config.appSecret)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                    Button { revealSecret.toggle() } label: {
                        Image(systemName: revealSecret ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundStyle(ConfigPalette.secondary(for: mode))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var connectionSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.connection, mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.feishuDomain, hint: "FEISHU_DOMAIN") {
                Picker("", selection: $config.domain) {
                    Text("feishu").tag("feishu")
                    Text("lark").tag("lark")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var accessSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.accessControl, mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.dmPolicy, hint: "FEISHU_DM_POLICY") {
                Picker("", selection: $config.dmPolicy) {
                    Text("open").tag("open")
                    Text("allowlist").tag("allowlist")
                    Text("pairing").tag("pairing")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.groupPolicy, hint: "FEISHU_GROUP_POLICY") {
                Picker("", selection: $config.groupPolicy) {
                    Text("open").tag("open")
                    Text("allowlist").tag("allowlist")
                    Text("disabled").tag("disabled")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            configRowDivider(mode: mode)
            boolRow(label: L10n.FeishuConfig.requireMention, hint: "FEISHU_REQUIRE_MENTION", value: $config.requireMention)
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.allowedUsers, hint: "FEISHU_ALLOW_FROM") {
                TextField("ou_abc,ou_def", text: $config.allowFrom)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.allowedGroups, hint: "FEISHU_ALLOW_GROUPS") {
                TextField("oc_abc,oc_def", text: $config.allowGroups)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private func boolRow(label: String, hint: String, value: Binding<Bool>) -> some View {
        configRow(mode: mode, label: label, hint: hint) {
            HStack {
                Toggle("", isOn: value).labelsHidden()
                Text(value.wrappedValue ? L10n.Config.enabled : L10n.Config.disabled)
                    .font(.system(size: 11))
                    .foregroundStyle(ConfigPalette.secondary(for: mode))
                Spacer()
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
                .disabled(!isValid)
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
