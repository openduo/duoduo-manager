import Foundation

enum SharedPresentationFormatting {
    static func compactIdentifier(_ value: String, head: Int = 9, tail: Int = 7, maxLength: Int = 20) -> String {
        if value.count <= maxLength { return value }
        return String(value.prefix(head)) + "…" + String(value.suffix(tail))
    }

    static func shortPartitionName(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(10)) + "…"
    }

    static func shortEventTypeName(_ type: String) -> String {
        guard let dot = type.lastIndex(of: ".") else { return type }
        return String(type[type.index(after: dot)...])
    }

    static func shortSessionKey(_ key: String, sessions: [SessionInfo]) -> String {
        if key.hasPrefix("meta:") { return String(key.dropFirst(5)) }
        if key.hasPrefix("job:") {
            let name = String(key.dropFirst(4))
            if let dot = name.lastIndex(of: ".") {
                let base = String(name[..<dot])
                let uid = String(name[name.index(after: dot)...].suffix(8))
                return "job:\(base).\(uid)"
            }
            return "job:\(name)"
        }
        if let session = sessions.first(where: { $0.session_key == key }),
           let displayName = session.display_name, !displayName.isEmpty {
            let label = displayName.count > 16 ? String(displayName.prefix(15)) + "…" : displayName
            let kind = key.split(separator: ":").first.map(String.init) ?? ""
            return "\(kind):\(label)"
        }
        let parts = key.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(String(parts.last!.suffix(8)))"
        }
        return String(key.suffix(16))
    }

    static func sessionSidebarLabel(_ key: String, sessions: [SessionInfo]) -> String {
        let session = sessions.first(where: { $0.session_key == key })
        let base = shortSessionKey(key, sessions: sessions)
        guard let caption = sessionRuntimeCaption(runtime: session?.runtime, model: session?.model) else {
            return base
        }
        return "\(base) · \(caption)"
    }

    static func systemHealthSummary(_ health: HealthInfo?) -> String {
        let gateway = health?.gateway ?? "unknown"
        let meta = health?.meta_session ?? "unknown"
        return "gw:\(gateway) · meta:\(meta)"
    }

    static func dashboardHealthText(_ health: HealthInfo?) -> String {
        health.map {
            "\($0.gateway == "ok" ? "gw:ok" : "gw:\($0.gateway)") \($0.meta_session == "ok" || $0.meta_session == "starting" ? "meta:ok" : "meta:\($0.meta_session)")"
        } ?? "no connection"
    }

    static func sessionDetail(_ session: SessionInfo) -> String {
        var parts: [String] = []
        if let caption = sessionRuntimeCaption(runtime: session.runtime, model: session.model) {
            parts.append(caption)
        }
        if let last = session.last_event_at { parts.append(timeAgo(last)) }
        if let health = session.health { parts.append(health) }
        return parts.isEmpty ? "idle" : parts.joined(separator: " · ")
    }

    /// Runtime plus served/pending model for a session row.
    /// `served → pending` when a stored `/model` has not reached the runtime yet.
    static func sessionRuntimeCaption(runtime: String?, model: SessionModelInfo?) -> String? {
        let runtimePart = normalizedRuntime(runtime)
        let modelPart = sessionModelCaption(model)
        switch (runtimePart, modelPart) {
        case let (runtime?, model?):
            return "\(runtime) · \(model)"
        case let (runtime?, nil):
            return runtime
        case let (nil, model?):
            return model
        default:
            return nil
        }
    }

    static func sessionModelCaption(_ model: SessionModelInfo?) -> String? {
        let served = normalizedRuntime(model?.served)
        let pending = normalizedRuntime(model?.pending)
        switch (served, pending) {
        case let (served?, pending?) where served != pending:
            return "\(served) → \(pending)"
        case let (served?, _):
            return served
        case let (nil, pending?):
            return "→ \(pending)"
        default:
            return nil
        }
    }

    static func normalizedRuntime(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func jobDetail(_ job: JobInfo, running: Bool) -> String {
        if running, let last = job.state?.last_run_at {
            return timeAgo(last)
        }
        if let cron = job.frontmatter?.cron, !cron.isEmpty {
            return cron
        }
        if let last = job.state?.last_run_at {
            return timeAgo(last)
        }
        return "idle"
    }

    // MARK: - Number / time formatting

    static func formatCost(_ n: Double) -> String {
        if n >= 1000 { return "$\((n / 1000).formatted(.number.precision(.fractionLength(1))))k" }
        return "$\(n.formatted(.number.precision(.fractionLength(2))))"
    }

    static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(Double(n / 1_000_000).formatted(.number.precision(.fractionLength(1))))M" }
        if n >= 1000 { return "\(Double(n / 1000).formatted(.number.precision(.fractionLength(0))))k" }
        return "\(n)"
    }

    static func formatTools(_ n: Int) -> String {
        if n >= 1000 { return "\(Double(n / 1000).formatted(.number.precision(.fractionLength(1))))k" }
        return "\(n)"
    }

    static func formatDuration(_ ms: Double?) -> String {
        guard let ms, ms.isFinite else { return String(describing: ms) }
        if ms < 1000 { return "\(Int(ms))ms" }
        let s = ms / 1000
        if s < 60 { return "\(s == s.rounded() ? String(Int(s)) : String(format: "%.1f", s))s (\(Int(ms).formatted())ms)" }
        let m = s / 60
        if m < 60 { return "\(m == m.rounded() ? String(Int(m)) : String(format: "%.1f", m))min (\(Int(ms).formatted())ms)" }
        let h = m / 60
        return "\(h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h))h (\(Int(ms).formatted())ms)"
    }

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func parseISO8601(_ s: String) -> Date {
        (try? Date(s, strategy: .iso8601)) ?? Date()
    }

    static func timeAgo(_ s: String) -> String {
        let seconds = Int(Date.now.timeIntervalSince(parseISO8601(s)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    static func prettyJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8)
        else { return "{}" }
        return str
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SS"
        return df
    }()
}
