import Foundation

enum ClaudeConfigFileService {
    enum SaveError: LocalizedError {
        case invalidAdvancedJSON
        case advancedJSONMustBeObject

        var errorDescription: String? {
            switch self {
            case .invalidAdvancedJSON:
                return "Advanced JSON is invalid."
            case .advancedJSONMustBeObject:
                return "Advanced JSON must be a JSON object."
            }
        }
    }

    static let targetPath = NSString(string: "~/.claude/kuaner.json").expandingTildeInPath

    static func buildJSON(preset: ClaudeConfigPreset) throws -> [String: Any] {
        var root: [String: Any] = [
            "env": preset.base.env,
            "includeCoAuthoredBy": preset.base.includeCoAuthoredBy
        ]

        let trimmedAdvanced = preset.advancedJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAdvanced.isEmpty, trimmedAdvanced != "{}" {
            guard let data = trimmedAdvanced.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data)
            else {
                throw SaveError.invalidAdvancedJSON
            }
            guard let advancedObject = obj as? [String: Any] else {
                throw SaveError.advancedJSONMustBeObject
            }
            merge(into: &root, patch: advancedObject)
        }

        return root
    }

    static func saveToDisk(preset: ClaudeConfigPreset) throws {
        let patch = try buildJSON(preset: preset)
        let url = URL(fileURLWithPath: targetPath)
        let dirURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        var root = try loadExistingJSONObject(from: url)
        merge(into: &root, patch: patch)
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }

    private static func loadExistingJSONObject(from url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return [:]
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private static func merge(into target: inout [String: Any], patch: [String: Any]) {
        for (key, value) in patch {
            if let nestedPatch = value as? [String: Any] {
                var nestedTarget = target[key] as? [String: Any] ?? [:]
                merge(into: &nestedTarget, patch: nestedPatch)
                target[key] = nestedTarget
            } else {
                target[key] = value
            }
        }
    }
}
