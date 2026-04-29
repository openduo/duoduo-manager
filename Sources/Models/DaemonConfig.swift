import Foundation

struct DaemonConfig: Sendable, Equatable {
    var workDir: String = ""
    var daemonHost: String = "127.0.0.1"
    var port: String = "20233"
    var logLevel: String = "info"
    var permissionMode: String = "default"

    static var defaultWorkDir: String {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .path
    }

    var daemonURL: String {
        "http://\(daemonHost):\(port)"
    }

    var host: String {
        get { daemonHost }
        set { daemonHost = newValue }
    }

    static func load(status: DaemonStatus? = nil) -> DaemonConfig {
        var values = mergeFallbackValues(ConfigStore.loadValues(), into: [:])
        values = mergeFallbackValues(ConfigStore.loadConfigJSONValues(), into: values)
        if let status {
            values = mergeFallbackValues(status.daemonConfigValues, into: values)
        }
        var config = DaemonConfig()
        config.workDir = values["ALADUO_WORK_DIR"] ?? config.workDir
        config.daemonHost = values["ALADUO_DAEMON_HOST"] ?? values["ALADUO_HOST"] ?? config.daemonHost
        config.port = values["ALADUO_PORT"] ?? config.port
        config.logLevel = values["ALADUO_LOG_LEVEL"] ?? config.logLevel
        config.permissionMode = values["ALADUO_PERMISSION_MODE"] ?? config.permissionMode
        return config
    }

    func save() {
        ConfigStore.save(entries: persistedEntries, managedKeys: Self.managedKeys)
        do {
            try ConfigStore.writeOnboardingConfigDocument(onboardingConfigDocument)
        } catch {
            NSLog("DaemonConfig save failed to sync config.json: \(error.localizedDescription)")
        }
    }

    var onboardingConfigDocument: OnboardingConfigDocument {
        OnboardingConfigDocument(
            mode: "local",
            daemonUrl: daemonURL,
            workDir: workDir.trimmingCharacters(in: .whitespacesAndNewlines),
            authSource: "claude_code_local"
        )
    }

    var persistedEntries: [(key: String, value: String)] {
        var entries: [(String, String)] = []
        appendIfNonEmpty(&entries, "ALADUO_WORK_DIR", workDir)
        appendIfDifferent(&entries, "ALADUO_DAEMON_HOST", daemonHost, defaultValue: "127.0.0.1")
        appendIfDifferent(&entries, "ALADUO_PORT", port, defaultValue: "20233")
        appendIfDifferent(&entries, "ALADUO_LOG_LEVEL", logLevel, defaultValue: "info")
        appendIfDifferent(&entries, "ALADUO_PERMISSION_MODE", permissionMode, defaultValue: "default")
        return entries
    }

    private static let managedKeys: Set<String> = [
        "ALADUO_WORK_DIR",
        "ALADUO_DAEMON_HOST",
        "ALADUO_HOST",
        "ALADUO_PORT",
        "ALADUO_LOG_LEVEL",
        "ALADUO_PERMISSION_MODE",
    ]

    private static func mergeFallbackValues(_ source: [String: String], into base: [String: String]) -> [String: String] {
        var normalized = source
        if let daemonURL = source["ALADUO_DAEMON_URL"] {
            let parsed = parseDaemonURL(daemonURL)
            if normalized["ALADUO_DAEMON_HOST"] == nil, let host = parsed.host {
                normalized["ALADUO_DAEMON_HOST"] = host
            }
            if normalized["ALADUO_PORT"] == nil, let port = parsed.port {
                normalized["ALADUO_PORT"] = port
            }
        }

        var merged = base
        for (key, value) in normalized {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if merged[key] == nil {
                merged[key] = value
            }
        }
        return merged
    }

    private static func parseDaemonURL(_ rawValue: String) -> (host: String?, port: String?) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) else { return (nil, nil) }
        return (components.host, components.port.map(String.init))
    }
}

struct OnboardingConfigDocument: Codable, Equatable {
    var mode: String
    var daemonUrl: String
    var workDir: String
    var authSource: String
}

func boolValue(_ rawValue: String?, default defaultValue: Bool) -> Bool {
    guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
        return defaultValue
    }
    switch value {
    case "1", "true", "yes", "on":
        return true
    case "0", "false", "no", "off":
        return false
    default:
        return defaultValue
    }
}

func appendIfNonEmpty(_ entries: inout [(String, String)], _ key: String, _ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    entries.append((key, trimmed))
}

func appendIfDifferent(_ entries: inout [(String, String)], _ key: String, _ value: String, defaultValue: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != defaultValue else { return }
    entries.append((key, trimmed))
}

func appendIfDifferent(_ entries: inout [(String, String)], _ key: String, _ value: Bool, defaultValue: Bool) {
    guard value != defaultValue else { return }
    entries.append((key, value ? "true" : "false"))
}
