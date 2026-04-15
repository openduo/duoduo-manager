import SwiftUI

extension DashboardView {
    var sidebarGroups: [DashboardSidebarGroupPresentation] {
        var seen = Set<String>()
        var groups: [DashboardSidebarGroupPresentation] = []

        for event in store.dashboard.events.reversed() {
            guard let key = event.session_key, !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)

            let filtered = store.dashboard.events.filter { $0.session_key == key }
            var counts: [String: Int] = [:]
            var order: [String] = []
            for item in filtered {
                if counts[item.type] == nil { order.append(item.type) }
                counts[item.type, default: 0] += 1
            }

            groups.append(
                DashboardSidebarGroupPresentation(
                    id: key,
                    key: key,
                    label: shortSessionKey(key, sessions: store.dashboard.sessions),
                    count: filtered.count,
                    eventTypes: order.map {
                        DashboardEventTypePresentation(
                            id: "\(key)__\($0)",
                            type: $0,
                            shortName: shortTypeName($0),
                            count: counts[$0] ?? 0,
                            color: DashboardTheme.color(forEventType: $0)
                        )
                    }
                )
            )
        }

        return groups
    }

    var systemEvents: [SpineEvent] {
        store.dashboard.events.filter { $0.session_key == nil || $0.session_key?.isEmpty == true }
    }

    var dashboardBottomStats: DashboardBottomStatsPresentation {
        let health = store.dashboard.health
        let isOk = health?.gateway == "ok" && (health?.meta_session == "ok" || health?.meta_session == "starting")
        let isErr = health?.gateway == "down" || health?.meta_session == "down"
        let color = isOk ? DashboardTheme.emerald : isErr ? DashboardTheme.red : DashboardTheme.amber

        return DashboardBottomStatsPresentation(
            costText: DashboardTheme.formatCost(store.dashboard.totalCost),
            tokenText: "tok:\(DashboardTheme.formatTokens(store.dashboard.totalTokens))",
            cacheText: "cache:\(store.dashboard.cacheHitRate)%",
            toolText: "tools:\(DashboardTheme.formatTools(store.dashboard.totalTools))",
            subconsciousItems: (store.dashboard.subconscious?.partitions ?? []).map { part in
                DashboardSubconsciousItemPresentation(
                    id: part.id,
                    marker: part.done ? "✓" : ".",
                    name: part.name,
                    markerColor: part.done ? DashboardTheme.emerald : DashboardTheme.amber,
                    textColor: part.done ? DashboardTheme.textSecondary : DashboardTheme.textTertiary
                )
            },
            healthText: health.map {
                "\($0.gateway == "ok" ? "gw:ok" : "gw:\($0.gateway)") \($0.meta_session == "ok" || $0.meta_session == "starting" ? "meta:ok" : "meta:\($0.meta_session)")"
            } ?? "no connection",
            healthColor: color
        )
    }

    func shortSessionKey(_ key: String, sessions: [SessionInfo]) -> String {
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

    func shortTypeName(_ type: String) -> String {
        guard let dot = type.lastIndex(of: ".") else { return type }
        return String(type[type.index(after: dot)...])
    }
}
