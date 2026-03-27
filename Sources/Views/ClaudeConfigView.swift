import SwiftUI
import AppKit

private enum ActionFeedbackState {
    case idle
    case success
    case failed
}

private struct ClaudePresetsTransfer: Codable {
    var presets: [ClaudeConfigPreset]
    var activePresetID: UUID?
}

struct ClaudeConfigView: View {
    @State private var presets: [ClaudeConfigPreset] = ClaudeConfigStorage.loadPresets()
    @State private var activePresetID: UUID = ClaudeConfigStorage.loadActivePresetID()
        ?? ClaudeConfigStorage.loadPresets().first?.id
        ?? ClaudeConfigStorage.defaultPreset.id
    @State private var isEditing = false
    @State private var editingPresetID: UUID?
    @State private var showAdvancedJSON = true
    @State private var saveState: ActionFeedbackState = .idle
    @State private var applyState: ActionFeedbackState = .idle
    @State private var feedbackTask: Task<Void, Never>?
    @State private var actionErrorMessage: String?
    @State private var jsonErrorMessage: String?
    @State private var isSyncingFromBaseToJSON = false
    @State private var isSyncingFromJSONToBase = false
    @State private var isSaving = false
    @State private var isApplying = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !isEditing {
                        listTabContent
                    } else {
                        editTabContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 560, height: 680)
        .onAppear {
            normalizeState()
            syncCurrentPresetJSONWithBase()
        }
        .onChange(of: activePresetID) {
            resetFeedbackState()
            jsonErrorMessage = nil
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if let currentPreset {
                Text("当前: \(currentPreset.name)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .separatorColor).opacity(0.2))
                    .clipShape(Capsule())
            }

            Spacer()

            if isEditing {
                Button("返回列表") {
                    isEditing = false
                    editingPresetID = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(saveButtonTitle) { saveWithAutoApply() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isSaving || isApplying || jsonErrorMessage != nil)
            }

            Menu {
                Button(L10n.ClaudeConfig.importPresets) { importPresets() }
                Button(L10n.ClaudeConfig.exportPresets) { exportPresets() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var listTabContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(ClaudeTemplateRegistry.builtIn) { template in
                        Button(template.name) {
                            createPresetFromTemplate(templateID: template.id)
                        }
                    }
                } label: {
                    Label("从模板创建", systemImage: "square.grid.2x2")
                }
                .controlSize(.small)
                Spacer()
            }

            if presets.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 120)
                    .overlay {
                        Text("暂无配置，请从模板创建或导入")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(presets) { preset in
                        presetRow(preset)
                    }
                }
            }
        }
    }

    private func presetRow(_ preset: ClaudeConfigPreset) -> some View {
        let selected = preset.id == activePresetID
        return Button {
            activePresetID = preset.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(fieldCount(for: preset)) 个字段")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    activePresetID = preset.id
                    isEditing = true
                    editingPresetID = preset.id
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    activePresetID = preset.id
                    deleteCurrentPreset()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(canDeletePreset(preset.id) ? .secondary : Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
                .disabled(!canDeletePreset(preset.id))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: selected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var editTabContent: some View {
        VStack(spacing: 10) {
            configRow(label: "配置名称", hint: "local") {
                TextField("配置名称", text: Binding(
                    get: { currentPreset?.name ?? "" },
                    set: { newName in
                        updateCurrentPreset { $0.name = newName }
                        resetFeedbackState()
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }

            formSection
            advancedSection
        }
    }

    private var formSection: some View {
        Group {
            configRow(label: "ANTHROPIC_AUTH_TOKEN", hint: "env") {
                SecureField("", text: Binding(
                    get: { currentBase.anthropicAuthToken },
                    set: { newValue in updateBase { $0.anthropicAuthToken = newValue } }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            }
            configRow(label: "ANTHROPIC_BASE_URL", hint: "env") {
                TextField("", text: Binding(
                    get: { currentBase.anthropicBaseURL },
                    set: { newValue in updateBase { $0.anthropicBaseURL = newValue } }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            }
            configRow(label: "models", hint: "env") {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        modelField(
                            title: "HAIKU",
                            value: Binding(
                                get: { currentBase.anthropicDefaultHaikuModel },
                                set: { newValue in updateBase { $0.anthropicDefaultHaikuModel = newValue } }
                            )
                        )
                        modelField(
                            title: "OPUS",
                            value: Binding(
                                get: { currentBase.anthropicDefaultOpusModel },
                                set: { newValue in updateBase { $0.anthropicDefaultOpusModel = newValue } }
                            )
                        )
                    }
                    HStack(spacing: 10) {
                        modelField(
                            title: "SONNET",
                            value: Binding(
                                get: { currentBase.anthropicDefaultSonnetModel },
                                set: { newValue in updateBase { $0.anthropicDefaultSonnetModel = newValue } }
                            )
                        )
                        modelField(
                            title: "MODEL",
                            value: Binding(
                                get: { currentBase.anthropicModel },
                                set: { newValue in updateBase { $0.anthropicModel = newValue } }
                            )
                        )
                    }
                }
            }
            configRow(label: "includeCoAuthoredBy", hint: "root") {
                Toggle("", isOn: Binding(
                    get: { currentBase.includeCoAuthoredBy },
                    set: { newValue in updateBase { $0.includeCoAuthoredBy = newValue } }
                ))
                .labelsHidden()
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.ClaudeConfig.advancedToggle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if let jsonErrorMessage {
                Text(jsonErrorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            } else if let actionErrorMessage {
                Text(actionErrorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            TextEditor(text: Binding(
                get: { currentPreset?.advancedJSON ?? "{}" },
                set: { newValue in
                    if isSyncingFromBaseToJSON { return }
                    updateCurrentPreset { $0.advancedJSON = newValue }
                    syncBaseFromCurrentJSON()
                    resetFeedbackState()
                }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 220)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(jsonErrorMessage == nil ? Color(nsColor: .separatorColor) : .red, lineWidth: 0.5)
            )
        }
    }

    private var currentPreset: ClaudeConfigPreset? {
        let targetID = isEditing ? (editingPresetID ?? activePresetID) : activePresetID
        return presets.first(where: { $0.id == targetID })
    }

    private var currentBase: ClaudeConfigBase {
        currentPreset?.base ?? ClaudeConfigBase()
    }

    private var saveButtonTitle: String {
        if isSaving || isApplying {
            return isApplying ? L10n.ClaudeConfig.applying : L10n.ClaudeConfig.saving
        }
        if applyState == .success {
            return L10n.ClaudeConfig.appliedShort
        }
        if saveState == .failed || applyState == .failed {
            return L10n.ClaudeConfig.saveFailed
        }
        switch saveState {
        case .idle: return L10n.Config.save
        case .success: return L10n.ClaudeConfig.savedShort
        case .failed: return L10n.ClaudeConfig.saveFailed
        }
    }

    private func normalizeState() {
        if presets.isEmpty {
            presets = [ClaudeConfigStorage.defaultPreset]
        }
        if !presets.contains(where: { $0.id == activePresetID }) {
            activePresetID = presets.first?.id ?? ClaudeConfigStorage.defaultPreset.id
        }
    }

    private func updateCurrentPreset(_ mutate: (inout ClaudeConfigPreset) -> Void) {
        let targetID = isEditing ? (editingPresetID ?? activePresetID) : activePresetID
        guard let index = presets.firstIndex(where: { $0.id == targetID }) else { return }
        mutate(&presets[index])
    }

    private func updateBase(_ mutate: (inout ClaudeConfigBase) -> Void) {
        guard !isSyncingFromJSONToBase else { return }
        updateCurrentPreset {
            var base = $0.base
            mutate(&base)
            $0.base = base
        }
        syncCurrentPresetJSONWithBase()
        jsonErrorMessage = nil
        resetFeedbackState()
    }

    private func persistPresets(showFeedback: Bool = true) {
        isSaving = true
        normalizeState()
        ClaudeConfigStorage.savePresets(presets)
        ClaudeConfigStorage.saveActivePresetID(activePresetID)
        isSaving = false
        if showFeedback {
            saveState = .success
            actionErrorMessage = nil
            scheduleFeedbackReset()
        }
    }

    private func saveWithAutoApply() {
        normalizeState()
        guard let preset = currentPreset else { return }
        persistPresets(showFeedback: false)

        let editedID = isEditing ? (editingPresetID ?? activePresetID) : activePresetID
        guard editedID == activePresetID else {
            saveState = .success
            applyState = .idle
            actionErrorMessage = nil
            isEditing = false
            editingPresetID = nil
            scheduleFeedbackReset()
            return
        }

        isApplying = true
        do {
            try ClaudeConfigFileService.saveToDisk(preset: preset)
            isApplying = false
            saveState = .success
            applyState = .success
            actionErrorMessage = nil
            isEditing = false
            editingPresetID = nil
            scheduleFeedbackReset()
        } catch {
            isApplying = false
            saveState = .failed
            applyState = .failed
            actionErrorMessage = error.localizedDescription
            scheduleFeedbackReset()
        }
    }

    private func exportPresets() {
        normalizeState()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-config-presets.json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = L10n.ClaudeConfig.exportPresets
        panel.message = L10n.ClaudeConfig.exportHint
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let transfer = ClaudePresetsTransfer(presets: presets, activePresetID: activePresetID)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(transfer)
            try data.write(to: url, options: .atomic)
            resetFeedbackState()
        } catch {
            applyState = .failed
            actionErrorMessage = error.localizedDescription
            scheduleFeedbackReset()
        }
    }

    private func importPresets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L10n.ClaudeConfig.importPresets
        panel.message = L10n.ClaudeConfig.importHint
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let transfer = try JSONDecoder().decode(ClaudePresetsTransfer.self, from: data)
            guard !transfer.presets.isEmpty else {
                applyState = .failed
                actionErrorMessage = L10n.ClaudeConfig.importEmpty
                scheduleFeedbackReset()
                return
            }

            var existingIDs = Set(presets.map(\.id))
            var imported = transfer.presets
            for idx in imported.indices {
                while existingIDs.contains(imported[idx].id) {
                    imported[idx].id = UUID()
                }
                existingIDs.insert(imported[idx].id)
            }

            presets.append(contentsOf: imported)
            activePresetID = imported.first?.id ?? activePresetID
            persistPresets()
            resetFeedbackState()
        } catch {
            applyState = .failed
            actionErrorMessage = error.localizedDescription
            scheduleFeedbackReset()
        }
    }

    private func syncCurrentPresetJSONWithBase() {
        guard let preset = currentPreset else { return }
        var root = (try? parseJSONObject(from: preset.advancedJSON)) ?? [:]
        let base = preset.base

        var env = root["env"] as? [String: Any] ?? [:]
        setEnvValue(&env, key: "ANTHROPIC_AUTH_TOKEN", value: base.anthropicAuthToken)
        setEnvValue(&env, key: "ANTHROPIC_BASE_URL", value: base.anthropicBaseURL)
        setEnvValue(&env, key: "ANTHROPIC_DEFAULT_HAIKU_MODEL", value: base.anthropicDefaultHaikuModel)
        setEnvValue(&env, key: "ANTHROPIC_DEFAULT_OPUS_MODEL", value: base.anthropicDefaultOpusModel)
        setEnvValue(&env, key: "ANTHROPIC_DEFAULT_SONNET_MODEL", value: base.anthropicDefaultSonnetModel)
        setEnvValue(&env, key: "ANTHROPIC_MODEL", value: base.anthropicModel)

        root["env"] = env
        root["includeCoAuthoredBy"] = base.includeCoAuthoredBy

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ),
              let text = String(data: data, encoding: .utf8)
        else { return }

        isSyncingFromBaseToJSON = true
        updateCurrentPreset { $0.advancedJSON = text }
        isSyncingFromBaseToJSON = false
        jsonErrorMessage = nil
    }

    private func syncBaseFromCurrentJSON() {
        guard let preset = currentPreset else { return }
        guard !isSyncingFromBaseToJSON else { return }
        do {
            let root = try parseJSONObject(from: preset.advancedJSON)
            let env = root["env"] as? [String: Any] ?? [:]
            isSyncingFromJSONToBase = true
            updateCurrentPreset { current in
                var base = current.base
                base.anthropicAuthToken = (env["ANTHROPIC_AUTH_TOKEN"] as? String) ?? ""
                base.anthropicBaseURL = (env["ANTHROPIC_BASE_URL"] as? String) ?? ""
                base.anthropicDefaultHaikuModel = (env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] as? String) ?? ""
                base.anthropicDefaultOpusModel = (env["ANTHROPIC_DEFAULT_OPUS_MODEL"] as? String) ?? ""
                base.anthropicDefaultSonnetModel = (env["ANTHROPIC_DEFAULT_SONNET_MODEL"] as? String) ?? ""
                base.anthropicModel = (env["ANTHROPIC_MODEL"] as? String) ?? ""
                if let include = root["includeCoAuthoredBy"] as? Bool {
                    base.includeCoAuthoredBy = include
                }
                current.base = base
            }
            isSyncingFromJSONToBase = false
            jsonErrorMessage = nil
        } catch {
            isSyncingFromJSONToBase = false
            jsonErrorMessage = L10n.ClaudeConfig.invalidJSON
        }
    }

    private func resetFeedbackState() {
        feedbackTask?.cancel()
        saveState = .idle
        applyState = .idle
        actionErrorMessage = nil
    }

    private func scheduleFeedbackReset(after seconds: Double = 2.5) {
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                saveState = .idle
                applyState = .idle
                actionErrorMessage = nil
            }
        }
    }

    private func createPresetFromTemplate(templateID: String) {
        guard let template = ClaudeTemplateRegistry.template(id: templateID) else { return }
        var newPreset = ClaudeConfigPreset(
            id: UUID(),
            name: template.name,
            base: ClaudeConfigBase(),
            advancedJSON: "{}"
        )
        newPreset.applyTemplate(template, preserveToken: true)
        presets.append(newPreset)
        editingPresetID = newPreset.id
        isEditing = true
        syncCurrentPresetJSONWithBase()
        persistPresets()
    }

    private func fieldCount(for preset: ClaudeConfigPreset) -> Int {
        do {
            let root = try parseJSONObject(from: preset.advancedJSON)
            let env = root["env"] as? [String: Any] ?? [:]
            var count = env.count
            if root["includeCoAuthoredBy"] != nil {
                count += 1
            }
            return count
        } catch {
            return 0
        }
    }

    private func deleteCurrentPreset() {
        let targetID = editingPresetID ?? activePresetID
        guard canDeletePreset(targetID) else { return }
        guard let index = presets.firstIndex(where: { $0.id == targetID }) else { return }
        presets.remove(at: index)
        activePresetID = presets.first?.id ?? ClaudeConfigStorage.defaultPreset.id
        if editingPresetID == targetID {
            editingPresetID = nil
            isEditing = false
        }
        persistPresets()
    }

    private var canDeleteEditingPreset: Bool {
        canDeletePreset(editingPresetID ?? activePresetID)
    }

    private func canDeletePreset(_ presetID: UUID) -> Bool {
        presetID != activePresetID && presets.count > 1
    }

    private func parseJSONObject(from text: String) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [:]
        }
        let data = Data(trimmed.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func setEnvValue(_ env: inout [String: Any], key: String, value: String) {
        if value.isEmpty {
            env.removeValue(forKey: key)
        } else {
            env[key] = value
        }
    }

    private func nextPresetName() -> String {
        var index = presets.count + 1
        while presets.contains(where: { $0.name == "Preset \(index)" }) {
            index += 1
        }
        return "Preset \(index)"
    }

    private func modelField(title: String, value: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            TextField("", text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }
}
