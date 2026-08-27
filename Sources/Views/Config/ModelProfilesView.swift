import AppKit
import SwiftUI

struct ModelProfilesView: View {
    @Bindable var store: AppStore
    @State private var editorDraft: ModelProfileDraft?
    @State private var pendingDelete: ModelProfileEntry?
    @State private var aliasDrafts: [String: String] = [:]

    private var profiles: ModelProfileStore { store.modelProfiles }
    private var presentation: ModelProfilesPresentation {
        ModelProfilePresentationMapper.make(store: profiles)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = presentation.errorMessage, !error.isEmpty {
                banner(error, tint: .red)
            } else if let info = presentation.infoMessage, !info.isEmpty {
                banner(info, tint: .orange)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profilesSection
                    aliasesSection
                    Text(L10n.ModelProfiles.rebuildNote)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .task(id: reloadKey) {
            await reload()
        }
        .onChange(of: presentation.aliasRows.map(\.modelID).joined(separator: ",")) { _, _ in
            syncAliasDrafts()
        }
        .sheet(item: Binding(
            get: { editorDraft.map { EditorItem(draft: $0) } },
            set: { editorDraft = $0?.draft }
        )) { item in
            ModelProfileEditorSheet(
                draft: item.draft,
                errorMessage: profiles.errorMessage,
                isSaving: presentation.isSaving,
                onCancel: {
                    profiles.errorMessage = nil
                    editorDraft = nil
                },
                onSave: { draft in
                    Task {
                        if await profiles.save(draft) {
                            editorDraft = nil
                        }
                    }
                }
            )
        }
        .confirmationDialog(
            L10n.ModelProfiles.deleteTitle,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.ModelProfiles.remove, role: .destructive) {
                if let modelID = pendingDelete?.model {
                    Task { await profiles.delete(modelID: modelID) }
                }
                pendingDelete = nil
            }
            Button(L10n.Config.cancel, role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(L10n.ModelProfiles.deleteMessage(pendingDelete?.model ?? ""))
        }
    }

    private var reloadKey: String {
        "\(store.runtime.status.version)|\(store.runtime.status.isRunning)|\(profiles.scope.id)|\(store.runtime.channels.map(\.type).joined(separator: ","))"
    }

    private func reload() async {
        await profiles.reload(
            installedVersion: store.runtime.status.version,
            daemonRunning: store.runtime.status.isRunning,
            channels: store.runtime.channels
        )
        syncAliasDrafts()
    }

    private func syncAliasDrafts() {
        var next: [String: String] = [:]
        for row in presentation.aliasRows {
            next[row.tier] = aliasDrafts[row.tier] ?? row.modelID
        }
        aliasDrafts = next
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(L10n.ModelProfiles.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.ModelProfiles.claudeOnly)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
                Text(L10n.ModelProfiles.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Picker(L10n.ModelProfiles.layer, selection: Binding(
                get: { profiles.scope.id },
                set: { newID in
                    if let option = presentation.scopeOptions.first(where: { $0.id == newID }) {
                        profiles.scope = option.scope
                    }
                }
            )) {
                ForEach(presentation.scopeOptions) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 140)
            Button {
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L10n.ModelProfiles.refresh)
            .disabled(presentation.isLoading || presentation.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(tint.opacity(0.08))
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.ModelProfiles.profilesSection)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(L10n.ModelProfiles.add) {
                    profiles.errorMessage = nil
                    editorDraft = .fresh()
                }
                .disabled(presentation.isSaving || !store.runtime.status.isRunning)
            }

            if !presentation.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(presentation.issues, id: \.self) { issue in
                        Text(issue)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.06)))
            }

            if presentation.isEmpty {
                Text(L10n.ModelProfiles.empty)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    profileHeaderRow
                    ForEach(presentation.rows) { row in
                        profileRow(row)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
        }
    }

    private var profileHeaderRow: some View {
        HStack(spacing: 8) {
            Text(L10n.ModelProfiles.columnModel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.ModelProfiles.columnWindow)
                .frame(width: 120, alignment: .leading)
            Text(L10n.ModelProfiles.columnEndpoint)
                .frame(width: 160, alignment: .leading)
            Text(L10n.ModelProfiles.columnAuth)
                .frame(width: 140, alignment: .leading)
            Color.clear.frame(width: 72)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .separatorColor).opacity(0.25))
    }

    private func profileRow(_ row: ModelProfileRowPresentation) -> some View {
        HStack(spacing: 8) {
            Text(row.modelID)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.tokensLabel)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 120, alignment: .leading)
            Text(row.endpointLabel)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(row.isRouted ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 160, alignment: .leading)
            Text(row.authLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 140, alignment: .leading)
            HStack(spacing: 4) {
                Button(L10n.ModelProfiles.edit) {
                    if let entry = profiles.snapshot.entries.first(where: { $0.model == row.modelID }) {
                        profiles.errorMessage = nil
                        editorDraft = .from(entry)
                    }
                }
                .controlSize(.small)
                Button(role: .destructive) {
                    pendingDelete = profiles.snapshot.entries.first(where: { $0.model == row.modelID })
                } label: {
                    Image(systemName: "trash")
                }
                .controlSize(.small)
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .disabled(presentation.isSaving)
    }

    private var aliasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.ModelProfiles.aliasesSection)
                .font(.system(size: 12, weight: .semibold))
            Text(L10n.ModelProfiles.aliasesHint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(presentation.aliasRows) { row in
                HStack(spacing: 8) {
                    Text(row.tier)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 64, alignment: .leading)
                    TextField(L10n.ModelProfiles.aliasPlaceholder, text: aliasBinding(row.tier))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button(L10n.Config.save) {
                        Task { await profiles.saveAlias(tier: row.tier, modelID: aliasDrafts[row.tier] ?? "") }
                    }
                    .controlSize(.small)
                    .disabled(presentation.isSaving)
                    Button(L10n.ModelProfiles.aliasClear) {
                        aliasDrafts[row.tier] = ""
                        Task { await profiles.saveAlias(tier: row.tier, modelID: "") }
                    }
                    .controlSize(.small)
                    .disabled(presentation.isSaving || (aliasDrafts[row.tier] ?? "").isEmpty && row.modelID.isEmpty)
                }
            }
        }
    }

    private func aliasBinding(_ tier: String) -> Binding<String> {
        Binding(
            get: { aliasDrafts[tier] ?? "" },
            set: { aliasDrafts[tier] = $0 }
        )
    }
}

private struct EditorItem: Identifiable {
    let draft: ModelProfileDraft
    var id: String { draft.originalModelID ?? "new" }
}

private struct ModelProfileEditorSheet: View {
    @State var draft: ModelProfileDraft
    var errorMessage: String?
    var isSaving: Bool
    let onCancel: () -> Void
    let onSave: (ModelProfileDraft) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(draft.isEditing ? L10n.ModelProfiles.editorEditTitle : L10n.ModelProfiles.editorAddTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(L10n.Config.cancel, action: onCancel)
                Button(L10n.Config.save) { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.validate().isEmpty || isSaving)
            }
            .padding(14)
            Divider()
            Form {
                TextField(L10n.ModelProfiles.modelID, text: $draft.modelID)
                    .font(.system(size: 12, design: .monospaced))
                    .disabled(draft.isEditing)
                Text(L10n.ModelProfiles.modelIDHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField(L10n.ModelProfiles.windowTokens, text: $draft.tokensText)
                    .font(.system(size: 12, design: .monospaced))
                Text(L10n.ModelProfiles.windowTokensHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Toggle(L10n.ModelProfiles.routeToggle, isOn: $draft.routeToEndpoint)
                Text(L10n.ModelProfiles.routeHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if draft.routeToEndpoint {
                    TextField(L10n.ModelProfiles.baseURL, text: $draft.baseURL, prompt: Text(L10n.ModelProfiles.baseURLPlaceholder))
                        .font(.system(size: 12, design: .monospaced))
                    Picker(L10n.ModelProfiles.credential, selection: $draft.authField) {
                        Text(L10n.ModelProfiles.authToken).tag(ModelProfileAuthField.anthropicAuthToken)
                        Text(L10n.ModelProfiles.oauthToken).tag(ModelProfileAuthField.claudeCodeOAuthToken)
                    }
                    if let masked = draft.existingAuthMasked {
                        Text("\(L10n.ModelProfiles.existingToken): \(masked)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    SecureField(L10n.ModelProfiles.token, text: $draft.token)
                    Text(L10n.ModelProfiles.tokenRequiredAgain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if !draft.validate().isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(draft.validate().map(L10n.ModelProfiles.validationMessage), id: \.self) { message in
                            Text(message)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                    }
                } else if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480)
    }
}
