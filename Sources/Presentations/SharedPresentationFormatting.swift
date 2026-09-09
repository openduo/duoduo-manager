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
        if let last = session.last_event_at { parts.append(DashboardTheme.timeAgo(last)) }
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
            return DashboardTheme.timeAgo(last)
        }
        if let cron = job.frontmatter?.cron, !cron.isEmpty {
            return cron
        }
        if let last = job.state?.last_run_at {
            return DashboardTheme.timeAgo(last)
        }
        return "idle"
    }
}
