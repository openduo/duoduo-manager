import SwiftUI

struct FeishuConfigView: View {
    @Binding var config: FeishuConfig
    var mode: ConfigEditorMode = .panel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var revealSecret = false
    @State private var showAdvanced = false

    private var isValid: Bool {
        !config.appId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !config.appSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if mode == .panel {
                titleBar
                Divider()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    authSection
                    connectionSection
                    accessSection
                    renderSection
                    advancedToggle
                    if showAdvanced { advancedSection }
                }
                .padding(.bottom, 16)
            }
            if mode == .inline {
                Divider()
                inlineActions
            }
        }
        .frame(width: mode == .panel ? 380 : nil)
        .fixedSize(horizontal: false, vertical: mode == .panel)
    }

    // MARK: - Title Bar

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

            Spacer()

            Button(L10n.Config.save) {
                saveConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isValid)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Authentication

    private var authSection: some View {
        Group {
            HStack {
                configSectionLabel(L10n.FeishuConfig.auth)
                Spacer()
                Button {
                    if let url = URL(string: "https://open.feishu.cn/page/openclaw?form=multiAgent") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                        Text("创建机器人")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 14)
            }
            configRow(label: "App ID", required: true, hint: "FEISHU_APP_ID") {
                TextField("cli_xxxxxxxxxx", text: $config.appId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            configRowDivider()
            configRow(label: "App Secret", required: true, hint: "FEISHU_APP_SECRET") {
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
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.connection)
            configRow(label: L10n.FeishuConfig.feishuDomain, hint: "FEISHU_DOMAIN") {
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

    // MARK: - Access Control

    private var accessSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.accessControl)
            configRow(label: L10n.FeishuConfig.dmPolicy, hint: "FEISHU_DM_POLICY") {
                Picker("", selection: $config.dmPolicy) {
                    Text(L10n.FeishuConfig.dmPolicyOpen).tag("open")
                    Text(L10n.FeishuConfig.dmPolicyAllowlist).tag("allowlist")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            configRowDivider()
            configRow(label: L10n.FeishuConfig.groupPolicy, hint: "FEISHU_GROUP_POLICY") {
                Picker("", selection: $config.groupPolicy) {
                    Text("open").tag("open")
                    Text("allowlist").tag("allowlist")
                    Text("disabled").tag("disabled")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            configRowDivider()
            configRow(label: L10n.FeishuConfig.requireMention, hint: "FEISHU_REQUIRE_MENTION") {
                HStack {
                    Toggle("", isOn: $config.requireMention).labelsHidden()
                    Text(config.requireMention ? L10n.FeishuConfig.requireMentionOn : L10n.FeishuConfig.requireMentionOff)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if config.dmPolicy == "allowlist" || config.groupPolicy == "allowlist" {
                configRowDivider()
                configRow(label: L10n.FeishuConfig.allowedUsers, hint: "FEISHU_ALLOW_FROM") {
                    TextField("ou_abc, ou_def", text: $config.allowFrom)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            if config.groupPolicy == "allowlist" {
                configRowDivider()
                configRow(label: L10n.FeishuConfig.allowedGroups, hint: "FEISHU_ALLOW_GROUPS") {
                    TextField("oc_abc, oc_def", text: $config.allowGroups)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Rendering

    private var renderSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.render)
            configRow(label: L10n.FeishuConfig.renderMode, hint: "FEISHU_RENDER_MODE") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $config.renderMode) {
                        Text("auto").tag("auto")
                        Text("raw").tag("raw")
                        Text("card").tag("card")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(renderModeDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var renderModeDescription: String {
        switch config.renderMode {
        case "auto":  return L10n.FeishuConfig.renderModeDescAuto
        case "raw":   return L10n.FeishuConfig.renderModeDescRaw
        case "card":  return L10n.FeishuConfig.renderModeDescCard
        default:      return ""
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
                Text(L10n.FeishuConfig.advancedSettings)
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
            configRow(label: L10n.FeishuConfig.botOpenId, hint: "FEISHU_BOT_OPEN_ID") {
                TextField("ou_xxxxxxxxxx", text: $config.botOpenId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            configRowDivider()
            configRow(label: L10n.FeishuConfig.logLevel, hint: "FEISHU_LOG_LEVEL") {
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

    private var inlineActions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(L10n.Config.cancel) {
                onCancel?()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(L10n.Config.save) {
                saveConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isValid)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func saveConfig() {
        config.save()
        if let onSave {
            onSave()
        } else {
            dismiss()
        }
    }

}
