import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    let daemonURL: String
    private(set) var sessions: [SessionInfo] = []
    private(set) var health: HealthInfo?
    private(set) var subconscious: SubconsciousInfo?
    private(set) var cadence: CadenceInfo?
    private(set) var jobs: [JobInfo] = []
    private(set) var events: [SpineEvent] = []
    private(set) var totalCost: Double = 0
    private(set) var totalTokens: Int = 0
    private(set) var totalTools: Int = 0
    private(set) var autoFollow = true
    private(set) var config: SystemConfig?

    private var rpc: DashboardRPCService
    private var lastEventId: String?
    private var eventsTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    // Track last seen event timestamp per session (for running detection)
    private var lastSeenBySession: [String: Date] = [:]

    private let maxEvents = 2000

    init(daemonURL: String) {
        self.daemonURL = daemonURL
        self.rpc = DashboardRPCService(daemonURL: daemonURL)
    }

    func startPolling() {
        stopPolling()
        // Initial fetch
        Task { await fetchAll() }

        eventsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await self?.fetchEvents()
            }
        }

        statusTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.fetchStatus()
            }
        }
    }

    func stopPolling() {
        eventsTask?.cancel()
        statusTask?.cancel()
        eventsTask = nil
        statusTask = nil
    }

    func isJobRunning(_ jobId: String) -> Bool {
        let staleThreshold = TimeInterval(2 * 60)
        let now = Date()
        for (key, ts) in lastSeenBySession {
            if key == "job:\(jobId)" || key.hasPrefix("job:\(jobId).") {
                if now.timeIntervalSince(ts) < staleThreshold {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Private

    private func fetchAll() async {
        async let _: Void = fetchStatus()
        async let _: Void = fetchEvents()
    }

    private func fetchEvents() async {
        guard let response = try? await rpc.spineTail(afterId: lastEventId, limit: 200) else { return }
        guard !response.events.isEmpty else { return }

        events.append(contentsOf: response.events)

        // Track last seen per session
        for evt in response.events {
            if let key = evt.session_key, let ts = evt.ts {
                lastSeenBySession[key] = parseDate(ts)
            }
            lastEventId = evt.id
        }

        // Trim old events
        if events.count > maxEvents {
            events = Array(events.dropFirst(events.count - maxEvents))
        }
    }

    private func fetchStatus() async {
        async let statusReq = rpc.systemStatus()
        async let usageReq = rpc.usage()
        async let jobsReq = rpc.jobList()

        guard let status = try? await statusReq else { return }

        sessions = status.sessions
        health = status.health
        subconscious = status.subconscious
        cadence = status.cadence

        if let usage = try? await usageReq {
            var cost = 0.0
            var tokens = 0
            var tools = 0
            for (_, session) in usage.sessions {
                guard let s = session.summary else { continue }
                cost += s.total_cost_usd ?? 0
                tokens += (s.total_input_tokens ?? 0) + (s.total_output_tokens ?? 0) + (s.total_cache_read_tokens ?? 0)
                tools += s.total_tool_calls ?? 0
            }
            totalCost = cost
            totalTokens = tokens
            totalTools = tools
        }

        if let jobsResp = try? await jobsReq {
            jobs = jobsResp.jobs
        }
    }

    func fetchConfig() async {
        config = try? await rpc.systemConfig()
    }

    private func parseDate(_ s: String) -> Date {
        // ISO 8601 with optional fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s) ?? Date()
    }
}
