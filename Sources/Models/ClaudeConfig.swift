import Foundation

struct ClaudeConfigTemplate: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var base: ClaudeConfigBase
    var defaultJSON: String
}

struct ClaudeConfigBase: Codable, Sendable {
    var anthropicAuthToken: String = ""
    var anthropicBaseURL: String = ""
    var anthropicDefaultHaikuModel: String = ""
    var anthropicDefaultOpusModel: String = ""
    var anthropicDefaultSonnetModel: String = ""
    var anthropicModel: String = ""
    var includeCoAuthoredBy: Bool = false

    var env: [String: String] {
        var env: [String: String] = [:]
        if !anthropicAuthToken.isEmpty {
            env["ANTHROPIC_AUTH_TOKEN"] = anthropicAuthToken
        }
        if !anthropicBaseURL.isEmpty {
            env["ANTHROPIC_BASE_URL"] = anthropicBaseURL
        }
        if !anthropicDefaultHaikuModel.isEmpty {
            env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = anthropicDefaultHaikuModel
        }
        if !anthropicDefaultOpusModel.isEmpty {
            env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = anthropicDefaultOpusModel
        }
        if !anthropicDefaultSonnetModel.isEmpty {
            env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = anthropicDefaultSonnetModel
        }
        if !anthropicModel.isEmpty {
            env["ANTHROPIC_MODEL"] = anthropicModel
        }
        return env
    }
}

struct ClaudeConfigPreset: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String = "Default"
    var base: ClaudeConfigBase = ClaudeConfigBase()
    var advancedJSON: String = "{}"
}

enum ClaudeTemplateRegistry {
    static let builtIn: [ClaudeConfigTemplate] = [
        ClaudeConfigTemplate(
            id: "blank",
            name: "Blank",
            base: ClaudeConfigBase(),
            defaultJSON: "{}"
        ),
        ClaudeConfigTemplate(
            id: "glm5",
            name: "GLM-5 (BigModel)",
            base: ClaudeConfigBase(
                anthropicAuthToken: "",
                anthropicBaseURL: "https://open.bigmodel.cn/api/anthropic",
                anthropicDefaultHaikuModel: "glm-5-turbo",
                anthropicDefaultOpusModel: "glm-5-turbo",
                anthropicDefaultSonnetModel: "glm-5-turbo",
                anthropicModel: "glm-5-turbo",
                includeCoAuthoredBy: false
            ),
            defaultJSON: "{}"
        )
    ]

    static func template(id: String) -> ClaudeConfigTemplate? {
        builtIn.first(where: { $0.id == id })
    }
}

extension ClaudeConfigPreset {
    mutating func applyTemplate(_ template: ClaudeConfigTemplate, preserveToken: Bool = true) {
        let existingToken = base.anthropicAuthToken
        base = template.base
        if preserveToken {
            base.anthropicAuthToken = existingToken
        }
        advancedJSON = template.defaultJSON
    }
}

enum ClaudeConfigStorage {
    private static let presetsKey = "claude.config.presets.v1"
    private static let activePresetIDKey = "claude.config.activePresetId.v1"

    static let defaultPreset = ClaudeConfigPreset()

    static func loadPresets() -> [ClaudeConfigPreset] {
        let loaded = ConfigStore.load(defaultValue: [defaultPreset], forKey: presetsKey)
        return loaded.isEmpty ? [defaultPreset] : loaded
    }

    static func savePresets(_ presets: [ClaudeConfigPreset]) {
        ConfigStore.save(presets, forKey: presetsKey)
    }

    static func loadActivePresetID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: activePresetIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    static func saveActivePresetID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: activePresetIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activePresetIDKey)
        }
    }
}
