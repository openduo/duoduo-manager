import Foundation

enum ClaudeCLIError: LocalizedError {
    case notInstalled
    case loginFailed
    case configureFailed(String)
    case invalidSettingsFile

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return L10n.Onboard.errClaudeNotInstalled
        case .loginFailed:
            return L10n.Onboard.errLoginTimeout
        case .configureFailed(let message):
            return message
        case .invalidSettingsFile:
            return L10n.Onboard.errSettingsInvalid
        }
    }
}

struct ClaudeAuthStatus: Sendable {
    let loggedIn: Bool
    let authMethod: String?
    let apiProvider: String?
}

struct ClaudeCLIService: Sendable {
    static func authStatus() async throws -> ClaudeAuthStatus {
        let output = try await ShellService.run("claude", arguments: ["auth", "status"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCLIError.configureFailed(L10n.Onboard.errAuthOutputParse)
        }

        return ClaudeAuthStatus(
            loggedIn: json["loggedIn"] as? Bool ?? false,
            authMethod: json["authMethod"] as? String,
            apiProvider: json["apiProvider"] as? String
        )
    }

    static func isInstalled() async throws -> Bool {
        do {
            _ = try await ShellService.run("claude", arguments: ["--version"])
            return true
        } catch {
            return false
        }
    }

    static func version() async throws -> String? {
        do {
            let output = try await ShellService.run("claude", arguments: ["--version"])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    static func install() async throws {
        _ = try await ShellService.run(
            "npm",
            arguments: ["install", "-g", "@anthropic-ai/claude-code"],
            environment: NodeRuntime.environment
        )
    }

    static func login(useConsole: Bool = false) async throws {
        var args = ["auth", "login"]
        if useConsole {
            args.append("--console")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude"] + args
        process.environment = NodeRuntime.environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let termination = AsyncStream.makeStream(of: Void.self)
        process.terminationHandler = { _ in
            termination.continuation.finish()
        }

        try process.run()

        let maxWait: UInt64 = 5 * 60 * 1_000_000_000
        let pollInterval: UInt64 = 5_000_000_000
        var elapsed: UInt64 = 0

        while elapsed < maxWait {
            try await Task.sleep(nanoseconds: pollInterval)
            elapsed += pollInterval

            do {
                let status = try await authStatus()
                if status.loggedIn {
                    return
                }
            } catch {
                continue
            }
        }

        throw ClaudeCLIError.loginFailed
    }
}

struct LLMProviderPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let envVars: [String: String]

    static let glm = LLMProviderPreset(
        id: "glm",
        name: "智谱 GLM",
        icon: "sparkles.rectangle.stack.fill",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.1",
            "ANTHROPIC_REASONING_MODEL": "glm-5.1"
        ]
    )

    static let zai = LLMProviderPreset(
        id: "zai",
        name: "Z.AI",
        icon: "network.badge.shield.half.filled",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_MODEL": "glm-5",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-5",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5"
        ]
    )

    static let kimi = LLMProviderPreset(
        id: "kimi",
        name: "Kimi",
        icon: "moon.stars.fill",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://api.moonshot.cn/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_MODEL": "kimi-k2.5",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "kimi-k2.5",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k2.5",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "kimi-k2.5"
        ]
    )

    static let bailian = LLMProviderPreset(
        id: "bailian",
        name: "百炼",
        icon: "cube.transparent.fill",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://dashscope.aliyuncs.com/api/v1/apps/claude-code-proxy",
            "ANTHROPIC_AUTH_TOKEN": ""
        ]
    )

    static let minimax = LLMProviderPreset(
        id: "minimax",
        name: "MiniMax",
        icon: "waveform.path.ecg.rectangle.fill",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_MODEL": "MiniMax-M2.7",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.7",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.7",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7"
        ]
    )

    static let deepseek = LLMProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        icon: "bolt.horizontal.circle.fill",
        envVars: [
            "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_MODEL": "DeepSeek-V3.2",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "DeepSeek-V3.2",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "DeepSeek-V3.2",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "DeepSeek-V3.2"
        ]
    )

    static let official = LLMProviderPreset(
        id: "official",
        name: "Official (Anthropic)",
        icon: "lock.shield.fill",
        envVars: [:]
    )

    static let custom = LLMProviderPreset(
        id: "custom",
        name: L10n.Onboard.customProvider,
        icon: "slider.horizontal.3",
        envVars: [:]
    )

    static func allPresets() -> [LLMProviderPreset] {
        [.official, .glm, .zai, .kimi, .bailian, .minimax, .deepseek, .custom]
    }
}

struct ClaudeSettingsStore {
    let settingsURL: URL

    init(settingsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
        .appendingPathComponent("settings.json")) {
        self.settingsURL = settingsURL
    }

    func load() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: settingsURL)
        if data.isEmpty {
            return [:]
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCLIError.invalidSettingsFile
        }
        return jsonObject
    }

    func currentEnv() throws -> [String: String] {
        let raw = try load()
        guard let env = raw["env"] as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in env {
            if let stringValue = value as? String {
                result[key] = stringValue
            } else {
                result[key] = "\(value)"
            }
        }
        return result
    }

    func mergeEnv(_ vars: [String: String]) throws {
        var raw = try load()
        var env = (raw["env"] as? [String: Any]) ?? [:]
        for (key, value) in vars {
            env[key] = value
        }
        raw["env"] = env

        let dirURL = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let existingText = try? String(contentsOf: settingsURL, encoding: .utf8)

        let updatedText: String
        if let existingText, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updatedText = try mergeEnvText(into: existingText, env: env)
        } else {
            updatedText = try buildNewSettingsText(env: env)
        }

        try updatedText.write(to: settingsURL, atomically: true, encoding: .utf8)
    }

    private func buildNewSettingsText(env: [String: Any]) throws -> String {
        let envText = try serializeJSONObject(env, sortedKeys: true)
            .replacingOccurrences(of: "\n", with: "\n  ")
        return "{\n  \"env\": \(envText)\n}\n"
    }

    private func mergeEnvText(into text: String, env: [String: Any]) throws -> String {
        let envText = try serializeJSONObject(env, sortedKeys: true)

        if let range = try topLevelValueRange(in: text, forKey: "env") {
            return text.replacingCharacters(in: range, with: envText)
        }

        guard let insertIndex = text.lastIndex(of: "}") else {
            throw ClaudeCLIError.invalidSettingsFile
        }

        let prefix = text[..<insertIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let hasOtherKeys = prefix != "{"
        let insertion = hasOtherKeys
            ? ",\n  \"env\": \(indent(envText, spaces: 2))\n"
            : "\n  \"env\": \(indent(envText, spaces: 2))\n"

        return String(text[..<insertIndex]) + insertion + String(text[insertIndex...])
    }

    private func serializeJSONObject(_ object: [String: Any], sortedKeys: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
        if sortedKeys {
            options.insert(.sortedKeys)
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ClaudeCLIError.invalidSettingsFile
        }
        return text
    }

    private func indent(_ text: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text.replacingOccurrences(of: "\n", with: "\n\(prefix)")
    }

    private func topLevelValueRange(in text: String, forKey key: String) throws -> Range<String.Index>? {
        var index = text.startIndex
        var depth = 0
        var inString = false
        var escaping = false
        var expectingKey = false

        while index < text.endIndex {
            let char = text[index]

            if inString {
                if escaping {
                    escaping = false
                } else if char == "\\" {
                    escaping = true
                } else if char == "\"" {
                    inString = false
                }
                index = text.index(after: index)
                continue
            }

            switch char {
            case "\"":
                let keyStart = index
                inString = true
                let stringRange = try quotedStringRange(in: text, startingAt: keyStart)
                let keyName = String(text[text.index(after: keyStart)..<text.index(before: stringRange.upperBound)])
                index = stringRange.upperBound

                if depth == 1 && expectingKey && keyName == key {
                    index = try skipWhitespace(in: text, from: index)
                    guard index < text.endIndex, text[index] == ":" else {
                        throw ClaudeCLIError.invalidSettingsFile
                    }
                    index = text.index(after: index)
                    index = try skipWhitespace(in: text, from: index)
                    let valueRange = try jsonValueRange(in: text, startingAt: index)
                    return valueRange
                }
                continue
            case "{":
                depth += 1
                expectingKey = depth == 1 || depth > 1
            case "}":
                depth -= 1
                expectingKey = false
            case ",":
                expectingKey = depth == 1
            case ":":
                expectingKey = false
            default:
                break
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func quotedStringRange(in text: String, startingAt start: String.Index) throws -> Range<String.Index> {
        var index = text.index(after: start)
        var escaping = false

        while index < text.endIndex {
            let char = text[index]
            if escaping {
                escaping = false
            } else if char == "\\" {
                escaping = true
            } else if char == "\"" {
                return start..<text.index(after: index)
            }
            index = text.index(after: index)
        }

        throw ClaudeCLIError.invalidSettingsFile
    }

    private func skipWhitespace(in text: String, from start: String.Index) throws -> String.Index {
        var index = start
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        return index
    }

    private func jsonValueRange(in text: String, startingAt start: String.Index) throws -> Range<String.Index> {
        guard start < text.endIndex else {
            throw ClaudeCLIError.invalidSettingsFile
        }

        let first = text[start]
        if first == "{" || first == "[" {
            return try balancedValueRange(in: text, startingAt: start)
        }
        if first == "\"" {
            return try quotedStringRange(in: text, startingAt: start)
        }

        var index = start
        while index < text.endIndex {
            let char = text[index]
            if char == "," || char == "}" || char == "]" {
                break
            }
            index = text.index(after: index)
        }
        return start..<index
    }

    private func balancedValueRange(in text: String, startingAt start: String.Index) throws -> Range<String.Index> {
        let opening = text[start]
        let closing: Character = opening == "{" ? "}" : "]"
        var depth = 0
        var index = start
        var inString = false
        var escaping = false

        while index < text.endIndex {
            let char = text[index]

            if inString {
                if escaping {
                    escaping = false
                } else if char == "\\" {
                    escaping = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == opening {
                    depth += 1
                } else if char == closing {
                    depth -= 1
                    if depth == 0 {
                        return start..<text.index(after: index)
                    }
                }
            }

            index = text.index(after: index)
        }

        throw ClaudeCLIError.invalidSettingsFile
    }
}
