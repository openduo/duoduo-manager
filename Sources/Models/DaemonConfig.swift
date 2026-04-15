import Foundation

/// Daemon configuration, mapped to duoduo daemon environment variables
struct DaemonConfig: Codable, Sendable, Equatable {

    // MARK: - General
    /// Working directory for the duoduo daemon
    var workDir: String = ""

    // MARK: - Network
    /// Listen port
    var port: String = "20233"
    /// Daemon host (default: 127.0.0.1)
    var host: String = "127.0.0.1"

    /// Computed daemon URL from host + port
    var daemonURL: String {
        "http://\(host):\(port)"
    }

    // MARK: - Logging
    /// debug | info | warn | error
    var logLevel: String = "debug"

    // MARK: - Permissions
    /// default | bypassPermissions
    var permissionMode: String = "default"

    // MARK: - Session
    /// Maximum concurrent sessions
    var maxConcurrent: String = "10"

    // MARK: - Advanced
    /// Session idle timeout in milliseconds
    var sessionIdleMs: String = "3600000"
    /// Disable automatic main session creation
    var disableAutoMain: Bool = false
    /// Pull limit
    var pullLimit: String = "50"

    // MARK: - Helpers

    /// Whether any value differs from defaults
    var isCustomized: Bool {
        port != "20233"
            || host != "127.0.0.1"
            || logLevel != "debug"
            || permissionMode != "default"
            || maxConcurrent != "10"
            || sessionIdleMs != "3600000"
            || disableAutoMain != false
            || pullLimit != "50"
    }

    /// Only maps user-modified (non-default) values to avoid overriding daemon's own defaults
    var envVars: [String: String] {
        var env: [String: String] = [:]
        if !workDir.isEmpty                      { env["ALADUO_WORK_DIR"] = workDir }
        if port != "20233"                       { env["ALADUO_PORT"] = port }
        if host != "127.0.0.1"                   { env["ALADUO_HOST"] = host }
        if logLevel != "debug"                   { env["ALADUO_LOG_LEVEL"] = logLevel }
        if permissionMode != "default"           { env["ALADUO_PERMISSION_MODE"] = permissionMode }
        if maxConcurrent != "10"                 { env["ALADUO_SESSION_MAX_CONCURRENT"] = maxConcurrent }
        if sessionIdleMs != "3600000"            { env["ALADUO_SESSION_IDLE_MS"] = sessionIdleMs }
        if disableAutoMain                       { env["ALADUO_DISABLE_DAEMON_AUTO_MAIN"] = "true" }
        if pullLimit != "50"                     { env["ALADUO_PULL_LIMIT"] = pullLimit }
        return env
    }

    // MARK: - Persistence

    private static let udKey = "daemon_config_v1"

    static func load() -> DaemonConfig {
        ConfigStore.load(defaultValue: DaemonConfig(), forKey: udKey)
    }

    func save() {
        ConfigStore.save(self, forKey: DaemonConfig.udKey)
    }
}
