import SwiftUI

struct FeishuConfigView: View {
    @Binding var config: FeishuConfig
    var mode: ConfigEditorMode = .panel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

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
                Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
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
            ODKicker(text: L10n.FeishuConfig.title, tint: OpenDuo.textSecondary)

            Spacer()

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(ODPrimaryButtonStyle())
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
                        Image(systemName: "plus")
                            .font(.system(size: 9))
                        Text(L10n.Onboard.createBot)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(ODQuietButtonStyle())
                .padding(.horizontal, 14)
                .padding(.top, 14)
            }
            configRow(mode: mode, label: L10n.FeishuConfig.appID, required: true, hint: "FEISHU_APP_ID") {
                configTextField(text: $config.appId, placeholder: "cli_xxxxxxxxxx")
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
                    .textFieldStyle(.plain)
                    .font(.odMono(11))
                    .foregroundStyle(OpenDuo.textStrong)
                    .odField()

                    Button { revealSecret.toggle() } label: {
                        Image(systemName: revealSecret ? "eye.slash" : "eye")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(ODIconButtonStyle())
                }
            }
        }
    }

    private var connectionSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.connection, mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.feishuDomain, hint: "FEISHU_DOMAIN") {
                ODSegmentedPicker(
                    selection: $config.domain,
                    options: [("feishu", "feishu"), ("lark", "lark")]
                )
            }
        }
    }

    private var accessSection: some View {
        Group {
            configSectionLabel(L10n.FeishuConfig.accessControl, mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.dmPolicy, hint: "FEISHU_DM_POLICY") {
                ODSegmentedPicker(
                    selection: $config.dmPolicy,
                    options: [("open", "open"), ("allowlist", "allowlist"), ("pairing", "pairing")]
                )
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.groupPolicy, hint: "FEISHU_GROUP_POLICY") {
                ODSegmentedPicker(
                    selection: $config.groupPolicy,
                    options: [("open", "open"), ("allowlist", "allowlist"), ("disabled", "disabled")]
                )
            }
            configRowDivider(mode: mode)
            boolRow(label: L10n.FeishuConfig.requireMention, hint: "FEISHU_REQUIRE_MENTION", value: $config.requireMention)
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.allowedUsers, hint: "FEISHU_ALLOW_FROM") {
                configTextField(text: $config.allowFrom, placeholder: "ou_abc,ou_def")
            }
            configRowDivider(mode: mode)
            configRow(mode: mode, label: L10n.FeishuConfig.allowedGroups, hint: "FEISHU_ALLOW_GROUPS") {
                configTextField(text: $config.allowGroups, placeholder: "oc_abc,oc_def")
            }
        }
    }

    private func boolRow(label: String, hint: String, value: Binding<Bool>) -> some View {
        configRow(mode: mode, label: label, hint: hint) {
            HStack(spacing: 8) {
                ODToggle(isOn: value)
                Text(value.wrappedValue ? L10n.Config.enabled : L10n.Config.disabled)
                    .font(.system(size: 11))
                    .foregroundStyle(OpenDuo.textSecondary)
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
            .buttonStyle(ODOutlineButtonStyle())

            Button(saveButtonTitle, action: saveConfig)
                .buttonStyle(ODPrimaryButtonStyle())
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
