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

// MARK: - usage.get

struct UsageResponse: Decodable, Sendable {
    let sessions: [String: SessionUsage]
}

struct SessionUsage: Decodable, Sendable {
    let summary: UsageSummary?
}

struct UsageSummary: Decodable, Sendable {
    let total_cost_usd: Double?
    let total_input_tokens: Int?
    let total_output_tokens: Int?
    let total_cache_read_tokens: Int?
    let total_tool_calls: Int?
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
