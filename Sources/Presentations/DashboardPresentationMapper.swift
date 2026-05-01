import SwiftUI

@MainActor
enum DashboardPresentationMapper {
    static func make(store: AppStore) -> DashboardPresentationBundle {
        DashboardPresentationBundle(
            sidebarGroups: sidebarGroups(store: store),
            systemEvents: store.dashboard.events.filter { $0.session_key == nil || $0.session_key?.isEmpty == true },
            bottomStats: bottomStats(store: store)
        )
    }

    static func shortTypeName(_ type: String) -> String {
        SharedPresentationFormatting.shortEventTypeName(type)
    }

    private static func sidebarGroups(store: AppStore) -> [DashboardSidebarGroupPresentation] {
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
                    label: SharedPresentationFormatting.shortSessionKey(key, sessions: store.dashboard.sessions),
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

    private static func bottomStats(store: AppStore) -> DashboardBottomStatsPresentation {
        let health = store.dashboard.health
        let isOk = health?.gateway == "ok" && (health?.meta_session == "ok" || health?.meta_session == "starting")
        let isErr = health?.gateway == "down" || health?.meta_session == "down"
        let color = isOk ? DashboardTheme.emerald : isErr ? DashboardTheme.red : DashboardTheme.amber

        return DashboardBottomStatsPresentation(
            costText: DashboardTheme.formatCost(store.dashboard.totalCost),
            tokenText: "tok:\(DashboardTheme.formatTokens(store.dashboard.totalTokens))",
            cacheText: "cache:\(store.dashboard.cacheHitRate.map { "\($0)%" } ?? "--")",
            toolText: "tools:\(DashboardTheme.formatTools(store.dashboard.totalTools))",
            subconsciousItems: (store.dashboard.subconscious?.partitions ?? []).map { part in
                DashboardSubconsciousItemPresentation(
                    id: part.id,
                    marker: part.done ? "✓" : ".",
                    name: SharedPresentationFormatting.shortPartitionName(part.name),
                    markerColor: part.done ? DashboardTheme.emerald : DashboardTheme.amber,
                    textColor: part.done ? DashboardTheme.textSecondary : DashboardTheme.textTertiary
                )
            },
            healthText: SharedPresentationFormatting.dashboardHealthText(health),
            healthColor: color
        )
    }
}
