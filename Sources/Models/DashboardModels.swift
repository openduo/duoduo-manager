import Foundation

// MARK: - RPC Wrapper

struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable {
    let code: Int
    let message: String
}

// MARK: - system.status

struct SystemStatus: Decodable, Sendable {
    let sessions: [SessionInfo]
    let health: HealthInfo
    let subconscious: SubconsciousInfo?
    let cadence: CadenceInfo?
}

struct SessionInfo: Decodable, Sendable, Identifiable {
    var id: String { session_key }
    let session_key: String
    let status: String
    let health: String?
    let last_event_at: String?
    let created_at: String?
    let last_error: String?
    let cwd: String?
    let display_name: String?
}

struct HealthInfo: Decodable, Sendable {
    let gateway: String
    let meta_session: String
}

struct SubconsciousInfo: Decodable, Sendable {
    let partitions: [SubconsciousPartition]
}

struct SubconsciousPartition: Decodable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let done: Bool
}

struct CadenceInfo: Decodable, Sendable {
    let last_tick: String?
    let interval_ms: Int
}

// MARK: - usage.get (mode: "totals")

struct UsageTotalsResponse: Decodable, Sendable {
    let totals: UsageTotals
}

struct UsageTotals: Decodable, Sendable {
    let total_cost_usd: Double?
    let total_input_tokens: Int?
    let total_output_tokens: Int?
    let total_cache_read_tokens: Int?
    let total_tool_calls: Int?
    let cache: CacheBreakdown?
}

struct CacheBreakdown: Decodable, Sendable {
    let anthropic: CacheProtocolStats?
    let codex: CacheProtocolStats?
}

struct CacheProtocolStats: Decodable, Sendable {
    let cache_read_tokens: Int?
    let cache_create_tokens: Int?
    let fresh_input_tokens: Int?
    let cached_tokens: Int?
    let input_tokens: Int?
}

// MARK: - job.list

struct JobListResponse: Decodable, Sendable {
    let jobs: [JobInfo]
}

struct JobInfo: Decodable, Sendable, Identifiable {
    let id: String
    let frontmatter: JobFrontmatter?
    let state: JobState?
}

struct JobFrontmatter: Decodable, Sendable {
    let cron: String?
    let cwd_rel: String?
    let runtime: String?
}

struct JobState: Decodable, Sendable {
    let last_result: String?
    let run_count: Int?
    let last_run_at: String?
}

// MARK: - spine.tail

struct SpineTailResponse: Decodable, Sendable {
    let events: [SpineEvent]
}

struct SpineEvent: Codable, Sendable, Identifiable {
    let id: String
    let type: String
    let session_key: String?
    let ts: String?
    let payload: EventPayload?
}

// MARK: - Event Payload

/// All fields optional to support different event types
struct EventPayload: Codable, Sendable {
    // agent.tool_use
    let tool_name: String?
    let input_summary: String?

    // agent.tool_result
    let is_error: Bool?
    let summary: String?

    // agent.result / agent.error
    let text: String?
    let partition: String?

    // route.deliver
    let source_session_key: String?
    let payload: DeliverPayload?

    // job events
    let job_id: String?
    let cron: String?
    let error: String?

    // source (meta events)
    let source: EventSource?
}

struct EventSource: Codable, Sendable {
    let kind: String?
    let name: String?
}

struct DeliverPayload: Codable, Sendable {
    let notify_content: String?
    let text: String?
}

// MARK: - system.config

struct SystemConfig: Decodable, Sendable {
    let network: [String: ConfigEntry]?
    let sessions: [String: ConfigEntry]?
    let cadence: [String: ConfigEntry]?
    let transfer: [String: ConfigEntry]?
    let logging: [String: ConfigEntry]?
    let sdk: [String: ConfigEntry]?
    let paths: [String: ConfigEntry]?
    let subconscious: SubconsciousConfig?
}

struct ConfigEntry: Decodable, Sendable {
    let value: String?
    let source: String?

    private enum CodingKeys: String, CodingKey { case value, source }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        // value is heterogeneous: Int, Bool, String, or null
        let single = try? container.superDecoder(forKey: .value).singleValueContainer()
        if let v = try? single?.decode(String.self) { value = v }
        else if let v = try? single?.decode(Int.self) { value = String(v) }
        else if let v = try? single?.decode(Bool.self) { value = String(v) }
        else { value = nil }
    }
}

struct SubconsciousConfig: Decodable, Sendable {
    let partitions: [PartitionConfig]?
}

struct PartitionConfig: Decodable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let enabled: Bool
    let cooldown_ticks: Int?
    let max_duration_ms: Int?
}

// MARK: - Config Metadata

enum ConfigMeta {
    static let groupOrder = ["network", "sessions", "cadence", "transfer", "logging", "sdk", "paths"]

    static let groupLabels: [String: String] = [
        "network": "Network", "sessions": "Sessions", "cadence": "Cadence",
        "transfer": "Transfer", "logging": "Logging", "sdk": "SDK & Models", "paths": "Paths",
        "subconscious": "Subconscious"
    ]

    static let msKeys: Set<String> = [
        "idle_ms", "heartbeat_ms", "interval_ms", "runtime_lock_heartbeat_ms",
        "pull_wait_ms", "max_duration_ms"
    ]

    private static let envNames: [String: String] = [
        "port": "ALADUO_PORT", "daemon_host": "ALADUO_DAEMON_HOST",
        "max_concurrent_channel": "ALADUO_SESSION_MAX_CONCURRENT_CHANNEL", "max_concurrent_job": "ALADUO_SESSION_MAX_CONCURRENT_JOB",
        "idle_ms": "ALADUO_SESSION_IDLE_MS", "heartbeat_ms": "ALADUO_SESSION_HEARTBEAT_MS",
        "interval_ms": "ALADUO_CADENCE_INTERVAL_MS", "meta_max_quiet_ticks": "ALADUO_META_MAX_QUIET_TICKS",
        "runtime_lock_heartbeat_ms": "ALADUO_RUNTIME_LOCK_HEARTBEAT_MS",
        "pull_limit": "ALADUO_PULL_LIMIT", "pull_wait_ms": "ALADUO_PULL_WAIT_MS", "subscribe_replay_limit": "ALADUO_SUBSCRIBE_REPLAY_LIMIT",
        "log_level": "ALADUO_LOG_LEVEL", "sdk_debug": "ALADUO_SDK_DEBUG", "log_session_lifecycle": "ALADUO_LOG_SESSION_LIFECYCLE",
        "telemetry_enabled": "ALADUO_TELEMETRY_ENABLED",
        "permission_mode": "ALADUO_PERMISSION_MODE",
        "work_dir": "ALADUO_WORK_DIR", "bootstrap_dir": "ALADUO_BOOTSTRAP_DIR", "meta_prompt_path": "ALADUO_META_PROMPT_PATH"
    ]

    static func resolveEnvName(group: String, key: String) -> String {
        if group == "sdk" {
            if let name = envNames[key] { return name }
            if key.hasPrefix("model_") { return "ANTHROPIC_DEFAULT_" + key.dropFirst(6).uppercased() }
            if key == "base_url" { return "ANTHROPIC_BASE_URL" }
            return key.uppercased()
        }
        return envNames[key] ?? ""
    }
}

// MARK: - SystemConfig Extensions

extension SystemConfig {
    func entries(for group: String) -> [String: ConfigEntry]? {
        switch group {
        case "network": return network
        case "sessions": return sessions
        case "cadence": return cadence
        case "transfer": return transfer
        case "logging": return logging
        case "sdk": return sdk
        case "paths": return paths
        default: return nil
        }
    }

    func buildDotEnv() -> String {
        var lines = ["# duoduo daemon configuration", "# Generated from system.config at \(ISO8601DateFormatter().string(from: Date()))", ""]
        for group in ConfigMeta.groupOrder {
            guard let entries = entries(for: group) else { continue }
            var groupLines: [String] = []
            for (key, entry) in entries.sorted(by: { $0.key < $1.key }) {
                let envName = ConfigMeta.resolveEnvName(group: group, key: key)
                guard !envName.isEmpty, entry.source != "unset", let val = entry.value else { continue }
                groupLines.append("\(envName)=\(val)")
            }
            if !groupLines.isEmpty {
                lines.append("# \(ConfigMeta.groupLabels[group] ?? group)")
                lines.append(contentsOf: groupLines)
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }
}
