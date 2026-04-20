import Foundation

struct DaemonConfig: Sendable, Equatable {
    var workDir: String = ""
    var daemonHost: String = "127.0.0.1"
    var port: String = "20233"
    var logLevel: String = "info"
    var permissionMode: String = "default"

    var daemonURL: String {
        "http://\(daemonHost):\(port)"
    }

    var host: String {
        get { daemonHost }
        set { daemonHost = newValue }
    }

    static func load() -> DaemonConfig {
        let values = ConfigStore.loadValues()
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
